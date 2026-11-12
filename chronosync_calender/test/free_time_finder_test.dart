import 'package:chronosync/data/models/event_model.dart';
import 'package:chronosync/data/models/occurrence.dart';
import 'package:chronosync/features/free_time/free_time_finder.dart';
import 'package:flutter_test/flutter_test.dart';

final _event = EventModel(
  id: 'e',
  calendarId: 'cal',
  title: 'busy',
  start: DateTime(2026, 1, 5),
  end: DateTime(2026, 1, 6),
  updatedAt: DateTime(2026),
);

Occurrence _busy(int sh, int eh, {bool allDay = false}) => Occurrence(
      event: allDay
          ? EventModel(
              id: 'a',
              calendarId: 'cal',
              title: 'all day',
              start: DateTime(2026, 1, 5),
              end: DateTime(2026, 1, 6),
              allDay: true,
              updatedAt: DateTime(2026),
            )
          : _event,
      start: DateTime(2026, 1, 5, sh),
      end: DateTime(2026, 1, 5, eh),
      originalStart: DateTime(2026, 1, 5, sh),
      isGenerated: false,
    );

void main() {
  final day = DateTime(2026, 1, 5);

  test('gaps between events, inside working hours, long enough', () {
    final slots = FreeTimeFinder.find(
      day: day,
      occurrences: [_busy(10, 11), _busy(10, 12) /* overlaps */, _busy(14, 15)],
      workStartHour: 9,
      workEndHour: 17,
      minLength: const Duration(minutes: 60),
    );
    expect(slots.map((s) => s.start.hour).toList(), [9, 12, 15]);
    expect(slots.map((s) => s.end.hour).toList(), [10, 14, 17]);
  });

  test('a short gap is dropped when the minimum is longer', () {
    final slots = FreeTimeFinder.find(
      day: day,
      occurrences: [_busy(9, 10), _busy(11, 17)],
      workStartHour: 9,
      workEndHour: 17,
      minLength: const Duration(minutes: 90),
    );
    expect(slots, isEmpty);
  });

  test('all-day events do not block time', () {
    final slots = FreeTimeFinder.find(
      day: day,
      occurrences: [_busy(0, 0, allDay: true)],
      workStartHour: 9,
      workEndHour: 10,
      minLength: const Duration(minutes: 30),
    );
    expect(slots.length, 1);
    expect(slots.single.length, const Duration(hours: 1));
  });
}
