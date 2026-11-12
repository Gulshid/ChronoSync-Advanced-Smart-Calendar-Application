import 'package:chronosync_calender/data/services/quick_add_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// Thursday 12 November 2026, 10:00
final _now = DateTime(2026, 11, 12, 10);

void main() {
  test('tomorrow and a pm time', () {
    final r = QuickAddParser.parse('Lunch with Sara tomorrow 1pm', now: _now);
    expect(r.title, 'Lunch with Sara');
    expect(r.start, DateTime(2026, 11, 13, 13));
    expect(r.end, DateTime(2026, 11, 13, 14));
  });

  test('next weekday with a 24-hour time', () {
    final r = QuickAddParser.parse('Dentist next Monday at 9:30', now: _now);
    expect(r.title, 'Dentist');
    expect(r.start, DateTime(2026, 11, 16, 9, 30));
  });

  test('duration phrase sets the length', () {
    final r = QuickAddParser.parse('Gym tomorrow for 45 minutes', now: _now);
    expect(r.title, 'Gym');
    expect(r.start, DateTime(2026, 11, 13, 9));
    expect(r.end, DateTime(2026, 11, 13, 9, 45));
  });

  test('no date or time uses the next full hour', () {
    final r = QuickAddParser.parse('Call mom', now: _now);
    expect(r.title, 'Call mom');
    expect(r.start, DateTime(2026, 11, 12, 11));
  });

  test('all day with a month and day', () {
    final r = QuickAddParser.parse('Holiday all day on 25 Dec', now: _now);
    expect(r.allDay, isTrue);
    expect(r.title, 'Holiday');
    expect(r.start, DateTime(2026, 12, 25));
  });

  test('a time already in the past today moves to tomorrow', () {
    final r = QuickAddParser.parse('Standup 8am', now: _now);
    expect(r.start, DateTime(2026, 11, 13, 8));
  });
}
