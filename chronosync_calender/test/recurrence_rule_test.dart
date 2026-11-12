import 'package:chronosync_calender/data/recurrence/recurrence_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecurrenceRule.parse', () {
    test('reads frequency, interval and weekdays', () {
      final rule = RecurrenceRule.parse('FREQ=WEEKLY;INTERVAL=2;BYDAY=WE,MO');
      expect(rule.frequency, RecurFrequency.weekly);
      expect(rule.interval, 2);
      expect(rule.weekdays, [1, 3]); // sorted: Monday, Wednesday
    });

    test('round-trips through toRRule', () {
      const raw = 'FREQ=MONTHLY;COUNT=5';
      expect(RecurrenceRule.parse(raw).toRRule(), raw);
    });

    test('reads UNTIL as a UTC instant', () {
      final rule = RecurrenceRule.parse('FREQ=DAILY;UNTIL=20261231T235959Z');
      expect(rule.until, DateTime.utc(2026, 12, 31, 23, 59, 59));
    });

    test('rejects unsupported frequency', () {
      expect(() => RecurrenceRule.parse('FREQ=HOURLY'), throwsFormatException);
    });

    test('rejects unknown BYDAY values', () {
      expect(() => RecurrenceRule.parse('FREQ=WEEKLY;BYDAY=XX'), throwsFormatException);
    });
  });
}
