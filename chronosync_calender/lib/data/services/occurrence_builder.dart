import 'package:chronosync_calender/core/utils/date_helpers.dart';
import 'package:chronosync_calender/data/models/event_model.dart';
import 'package:chronosync_calender/data/models/occurrence.dart';
import 'package:chronosync_calender/data/models/recurrence_rule.dart';

/// Turns stored rows into the occurrences that fall inside a time window.
abstract final class OccurrenceBuilder {
  static const _maxPeriods = 20000;

  /// Local start times for [rule] anchored at [dtStart], within [from, to).
  ///
  /// Results come in order. COUNT includes occurrences that happen before [from].
  static Iterable<DateTime> starts({
    required DateTime dtStart,
    required RecurrenceRule rule,
    required DateTime from,
    required DateTime to,
  }) sync* {
    final weekdays = rule.weekdays.isEmpty ? [dtStart.weekday] : rule.weekdays;
    var emitted = 0;

    for (var period = 0; period < _maxPeriods; period++) {
      final candidates = _candidates(dtStart, rule, period, weekdays)..sort();
      for (final c in candidates) {
        if (c.isBefore(dtStart)) continue;
        if (rule.until != null && c.toUtc().isAfter(rule.until!)) return;
        if (rule.count != null && emitted >= rule.count!) return;
        if (!c.isBefore(to)) return;
        emitted++;
        if (!c.isBefore(from)) yield c;
      }
    }
  }

  /// Builds the occurrences from [events] that overlap [from, to).
  static List<Occurrence> build({
    required Iterable<EventModel> events,
    required DateTime from,
    required DateTime to,
  }) {
    final list = events.toList();
    final masters = {for (final e in list) if (e.rrule != null) e.id: e};

    // Slots that already have an override (moved or cancelled), grouped by series.
    final overridden = <String, Set<int>>{};
    for (final e in list) {
      final parent = e.parentId;
      final original = e.originalStart;
      if (parent != null && original != null) {
        overridden.putIfAbsent(parent, () => <int>{}).add(original.millisecondsSinceEpoch);
      }
    }

    final out = <Occurrence>[];
    for (final e in list) {
      if (e.isCancelled) continue;

      if (e.rrule == null) {
        final parent = e.parentId;
        final occ = Occurrence(
          event: e,
          start: e.start,
          end: e.end,
          originalStart: e.originalStart ?? e.start,
          isGenerated: false,
          series: parent == null ? null : masters[parent],
        );
        if (occ.overlaps(from, to)) out.add(occ);
        continue;
      }

      final rule = RecurrenceRule.parse(e.rrule!);
      final skip = overridden[e.id] ?? const <int>{};
      final lookback = e.end.difference(e.start) + const Duration(days: 1);
      for (final s in starts(dtStart: e.start, rule: rule, from: from.subtract(lookback), to: to)) {
        if (skip.contains(s.millisecondsSinceEpoch)) continue;
        final occ = Occurrence(
          event: e,
          start: s,
          end: _wallEnd(e, s),
          originalStart: s,
          isGenerated: true,
          series: e,
        );
        if (occ.overlaps(from, to)) out.add(occ);
      }
    }

    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  static List<DateTime> _candidates(DateTime dtStart, RecurrenceRule rule, int period, List<int> weekdays) {
    final h = dtStart.hour;
    final mi = dtStart.minute;
    final base = DateTime(dtStart.year, dtStart.month, dtStart.day);
    final step = period * rule.interval;

    if (rule.frequency == RecurFrequency.daily) {
      return [DateTime(base.year, base.month, base.day + step, h, mi)];
    }

    if (rule.frequency == RecurFrequency.weekly) {
      // Weeks start on Monday, so anchor on the Monday of the start week.
      final monday = base.day - (dtStart.weekday - 1) + step * 7;
      return [for (final wd in weekdays) DateTime(base.year, base.month, monday + (wd - 1), h, mi)];
    }

    if (rule.frequency == RecurFrequency.monthly) {
      final monthIndex = dtStart.month - 1 + step;
      final year = dtStart.year + monthIndex ~/ 12;
      final month = monthIndex % 12 + 1;
      final day = rule.monthDay ?? dtStart.day;
      if (day > daysInMonth(year, month)) return const [];
      return [DateTime(year, month, day, h, mi)];
    }

    // Yearly
    final year = dtStart.year + step;
    if (dtStart.day > daysInMonth(year, dtStart.month)) return const [];
    return [DateTime(year, dtStart.month, dtStart.day, h, mi)];
  }

  /// Keeps the same end wall-clock time and day span as the series event.
  static DateTime _wallEnd(EventModel e, DateTime start) {
    final spanDays = calendarDaysBetween(e.start, e.end);
    return DateTime(start.year, start.month, start.day + spanDays, e.end.hour, e.end.minute);
  }
}
