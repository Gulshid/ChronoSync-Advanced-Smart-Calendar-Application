import 'package:chronosync_calender/core/utils/date_helpers.dart';
import 'package:chronosync_calender/data/models/occurrence.dart';

class FreeSlot {
  const FreeSlot(this.start, this.end);

  final DateTime start;
  final DateTime end;

  Duration get length => end.difference(start);
}

/// Finds gaps between timed events on one day, inside working hours.
/// All-day events do not block time.
abstract final class FreeTimeFinder {
  static List<FreeSlot> find({
    required DateTime day,
    required List<Occurrence> occurrences,
    required int workStartHour,
    required int workEndHour,
    required Duration minLength,
  }) {
    final dayStart = startOfDay(day);
    final windowStart = DateTime(dayStart.year, dayStart.month, dayStart.day, workStartHour);
    final windowEnd = DateTime(dayStart.year, dayStart.month, dayStart.day, workEndHour);

    final busy = <({DateTime start, DateTime end})>[];
    for (final o in occurrences) {
      if (o.isAllDay || !o.overlaps(windowStart, windowEnd)) continue;
      busy.add((
        start: o.start.isAfter(windowStart) ? o.start : windowStart,
        end: o.end.isBefore(windowEnd) ? o.end : windowEnd,
      ));
    }
    busy.sort((a, b) => a.start.compareTo(b.start));

    final slots = <FreeSlot>[];
    var cursor = windowStart;
    for (final b in busy) {
      if (b.start.isAfter(cursor)) slots.add(FreeSlot(cursor, b.start));
      if (b.end.isAfter(cursor)) cursor = b.end;
    }
    if (windowEnd.isAfter(cursor)) slots.add(FreeSlot(cursor, windowEnd));

    return slots.where((s) => s.length >= minLength).toList();
  }
}
