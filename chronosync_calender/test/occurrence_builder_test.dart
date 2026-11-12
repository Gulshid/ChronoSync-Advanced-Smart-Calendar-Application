import 'package:chronosync_calender/data/models/event_model.dart';
import 'package:chronosync_calender/data/services/occurrence_builder.dart';
import 'package:chronosync_calender/data/models/recurrence_rule.dart';
import 'package:flutter_test/flutter_test.dart';

EventModel _series(String rrule, DateTime start, {Duration length = const Duration(hours: 1)}) => EventModel(
      id: 'master',
      calendarId: 'cal',
      title: 'Series',
      start: start,
      end: start.add(length),
      rrule: rrule,
      updatedAt: DateTime(2026),
    );

List<DateTime> _starts(EventModel e, DateTime from, DateTime to) =>
    OccurrenceBuilder.build(events: [e], from: from, to: to).map((o) => o.start).toList();

void main() {
  group('OccurrenceBuilder', () {
    test('DAILY with COUNT stops after the count', () {
      final e = _series('FREQ=DAILY;COUNT=3', DateTime(2026, 1, 1, 9));
      final starts = _starts(e, DateTime(2026, 1, 1), DateTime(2026, 1, 10));
      expect(starts, [DateTime(2026, 1, 1, 9), DateTime(2026, 1, 2, 9), DateTime(2026, 1, 3, 9)]);
    });

    test('WEEKLY BYDAY produces the chosen weekdays only', () {
      // 5 January 2026 is a Monday.
      final e = _series('FREQ=WEEKLY;BYDAY=MO,WE', DateTime(2026, 1, 5, 9));
      final starts = _starts(e, DateTime(2026, 1, 5), DateTime(2026, 1, 12));
      expect(starts, [DateTime(2026, 1, 5, 9), DateTime(2026, 1, 7, 9)]);
    });

    test('MONTHLY on the 31st skips months without a 31st', () {
      final e = _series('FREQ=MONTHLY', DateTime(2026, 1, 31, 9));
      final starts = _starts(e, DateTime(2026, 1, 1), DateTime(2026, 5, 1));
      expect(starts, [DateTime(2026, 1, 31, 9), DateTime(2026, 3, 31, 9)]);
    });

    test('YEARLY on 29 February occurs only in leap years', () {
      final e = _series('FREQ=YEARLY', DateTime(2024, 2, 29, 9));
      final starts = _starts(e, DateTime(2024, 1, 1), DateTime(2030, 1, 1));
      expect(starts, [DateTime(2024, 2, 29, 9), DateTime(2028, 2, 29, 9)]);
    });

    test('INTERVAL skips periods', () {
      final e = _series('FREQ=DAILY;INTERVAL=3;COUNT=3', DateTime(2026, 1, 1, 9));
      final starts = _starts(e, DateTime(2026, 1, 1), DateTime(2026, 2, 1));
      expect(starts, [DateTime(2026, 1, 1, 9), DateTime(2026, 1, 4, 9), DateTime(2026, 1, 7, 9)]);
    });

    test('UNTIL is inclusive and stops the series', () {
      final until = DateTime(2026, 1, 3, 9).toUtc();
      final rule = RecurrenceRule.parse('FREQ=DAILY').copyWith(until: until);
      final e = _series(rule.toRRule(), DateTime(2026, 1, 1, 9));
      expect(_starts(e, DateTime(2026, 1, 1), DateTime(2026, 2, 1)).length, 3);
    });

    test('COUNT includes occurrences before the window', () {
      final e = _series('FREQ=DAILY;COUNT=3', DateTime(2026, 1, 1, 9));
      // Window starts on the third day, which is the last occurrence.
      final starts = _starts(e, DateTime(2026, 1, 3), DateTime(2026, 1, 10));
      expect(starts, [DateTime(2026, 1, 3, 9)]);
    });

    test('a cancelled occurrence is removed from the series', () {
      final master = _series('FREQ=DAILY;COUNT=3', DateTime(2026, 1, 1, 9));
      final cancelled = EventModel(
        id: 'override',
        calendarId: 'cal',
        title: 'Series',
        start: DateTime(2026, 1, 2, 9),
        end: DateTime(2026, 1, 2, 10),
        parentId: 'master',
        originalStart: DateTime(2026, 1, 2, 9),
        isCancelled: true,
        updatedAt: DateTime(2026),
      );
      final starts = OccurrenceBuilder.build(
        events: [master, cancelled],
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 10),
      ).map((o) => o.start).toList();
      expect(starts, [DateTime(2026, 1, 1, 9), DateTime(2026, 1, 3, 9)]);
    });

    test('a moved occurrence replaces its original slot', () {
      final master = _series('FREQ=DAILY;COUNT=2', DateTime(2026, 1, 1, 9));
      final moved = EventModel(
        id: 'override',
        calendarId: 'cal',
        title: 'Moved',
        start: DateTime(2026, 1, 1, 15),
        end: DateTime(2026, 1, 1, 16),
        parentId: 'master',
        originalStart: DateTime(2026, 1, 1, 9),
        updatedAt: DateTime(2026),
      );
      final occs = OccurrenceBuilder.build(
        events: [master, moved],
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 3),
      );
      expect(occs.map((o) => o.start).toList(), [DateTime(2026, 1, 1, 15), DateTime(2026, 1, 2, 9)]);
      expect(occs.first.isRecurring, isTrue);
    });

    test('multi-day occurrences keep their span', () {
      final e = _series('FREQ=WEEKLY;COUNT=1', DateTime(2026, 1, 5, 22), length: const Duration(hours: 4));
      final occ = OccurrenceBuilder.build(events: [e], from: DateTime(2026, 1, 5), to: DateTime(2026, 1, 6)).single;
      expect(occ.end, DateTime(2026, 1, 6, 2));
    });
  });
}
