import 'package:flutter_test/flutter_test.dart';

import 'package:chronosync_calender/data/services/ics_reader.dart';
import 'package:chronosync_calender/data/services/ics_writer.dart';
import 'package:chronosync_calender/data/models/event_model.dart';

void main() {
  final updated = DateTime(2026, 11, 12, 9);

  final series = EventModel(
    id: 'series1',
    calendarId: 'work',
    title: 'Standup, daily',
    location: 'Room 4',
    notes: 'Line one\nLine two; done',
    start: DateTime(2026, 11, 9, 9, 30),
    end: DateTime(2026, 11, 9, 9, 45),
    rrule: 'FREQ=WEEKLY;BYDAY=MO,WE;COUNT=6',
    reminderMinutes: const [10, 1440],
    updatedAt: updated,
  );
  final moved = EventModel(
    id: 'moved1',
    calendarId: 'work',
    title: 'Standup, daily',
    start: DateTime(2026, 11, 11, 15),
    end: DateTime(2026, 11, 11, 15, 15),
    parentId: 'series1',
    originalStart: DateTime(2026, 11, 11, 9, 30),
    updatedAt: updated,
  );
  final cancelled = EventModel(
    id: 'gone1',
    calendarId: 'work',
    title: 'Standup, daily',
    start: DateTime(2026, 11, 16, 9, 30),
    end: DateTime(2026, 11, 16, 9, 45),
    parentId: 'series1',
    originalStart: DateTime(2026, 11, 16, 9, 30),
    isCancelled: true,
    updatedAt: updated,
  );
  final holiday = EventModel(
    id: 'hol1',
    calendarId: 'holidays',
    title: 'Holiday',
    start: DateTime(2026, 12, 25),
    end: DateTime(2026, 12, 26),
    allDay: true,
    updatedAt: updated,
  );
  final single = EventModel(
    id: 'one1',
    calendarId: 'personal',
    title: 'Dentist',
    start: DateTime(2026, 11, 20, 10),
    end: DateTime(2026, 11, 20, 11),
    reminderMinutes: const [60],
    updatedAt: updated,
  );

  final text = IcsWriter.build(
    events: [series, moved, cancelled, holiday, single],
    calendarNames: {'work': 'Work', 'holidays': 'Holidays', 'personal': 'Personal'},
  );
  final read = IcsReader.read(text);

  // The series master's record, not its moved occurrence (both share one UID).
  IcsRecord masterRecord(String uid) =>
      read.records.firstWhere((r) => r.uid == uid && r.recurrenceId == null);

  test('the file is a calendar with the expected events', () {
    expect(text.startsWith('BEGIN:VCALENDAR'), isTrue);
    expect(text.trimRight().endsWith('END:VCALENDAR'), isTrue);
    expect(read.records.where((r) => r.recurrenceId == null).length, 3);
    expect(read.records.where((r) => r.recurrenceId != null).length, 1);
  });

  test('commas, semicolons and line breaks survive', () {
    final r = masterRecord('series1@chronosync');
    expect(r.title, 'Standup, daily');
    expect(r.notes, 'Line one\nLine two; done');
    expect(r.location, 'Room 4');
  });

  test('the repeat rule and cancelled occurrences survive', () {
    final r = masterRecord('series1@chronosync');
    expect(r.rrule, 'FREQ=WEEKLY;BYDAY=MO,WE;COUNT=6');
    expect(r.exdates.length, 1);
    expect(r.exdates.single.isAtSameMomentAs(DateTime(2026, 11, 16, 9, 30)), isTrue);
  });

  test('reminders survive', () {
    expect(masterRecord('series1@chronosync').reminders, [10, 1440]);
  });

  test('all-day events stay all-day with the same dates', () {
    final r = masterRecord('hol1@chronosync');
    expect(r.allDay, isTrue);
    expect(r.start, DateTime(2026, 12, 25));
    expect(r.end, DateTime(2026, 12, 26));
  });

  test('a moved occurrence keeps its new time and its original slot', () {
    final r = read.records.firstWhere((r) => r.recurrenceId != null);
    expect(r.start.isAtSameMomentAs(DateTime(2026, 11, 11, 15)), isTrue);
    expect(r.recurrenceId!.isAtSameMomentAs(DateTime(2026, 11, 11, 9, 30)), isTrue);
  });

  test('timed events come back at the same moment', () {
    final r = masterRecord('one1@chronosync');
    expect(r.allDay, isFalse);
    expect(r.start.isAtSameMomentAs(DateTime(2026, 11, 20, 10)), isTrue);
    expect(r.end.isAtSameMomentAs(DateTime(2026, 11, 20, 11)), isTrue);
  });
}
