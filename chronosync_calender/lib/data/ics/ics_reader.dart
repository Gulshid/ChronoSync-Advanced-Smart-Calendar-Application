import 'package:timezone/timezone.dart' as tz;

import '../recurrence/recurrence_rule.dart';
import 'ics_codec.dart';

/// One event read from an .ics file, before it is matched against the database.
class IcsRecord {
  const IcsRecord({
    required this.uid,
    required this.calendarName,
    required this.title,
    required this.location,
    required this.notes,
    required this.allDay,
    required this.start,
    required this.end,
    this.rrule,
    this.recurrenceId,
    this.exdates = const [],
    this.reminders = const [],
  });

  final String? uid;
  final String? calendarName;
  final String title;
  final String location;
  final String notes;
  final bool allDay;
  final DateTime start;
  final DateTime end;
  final String? rrule;

  /// Set for a moved occurrence: the slot it replaces.
  final DateTime? recurrenceId;

  /// Cancelled occurrences of this series.
  final List<DateTime> exdates;
  final List<int> reminders;
}

class IcsReadResult {
  const IcsReadResult(this.records, this.rulesSkipped);

  final List<IcsRecord> records;

  /// Events whose repeat rule could not be understood. They are imported as single events.
  final int rulesSkipped;
}

abstract final class IcsReader {
  static IcsReadResult read(String text) {
    final records = <IcsRecord>[];
    var rulesSkipped = 0;

    List<IcsProperty>? props;
    var reminders = <int>[];
    var inAlarm = false;
    String? trigger;

    for (final line in IcsCodec.unfold(text)) {
      final prop = IcsCodec.parseLine(line);
      if (prop == null) continue;

      if (prop.name == 'BEGIN' && prop.value == 'VEVENT') {
        props = [];
        reminders = [];
        continue;
      }
      if (prop.name == 'BEGIN' && prop.value == 'VALARM') {
        inAlarm = true;
        trigger = null;
        continue;
      }
      if (prop.name == 'END' && prop.value == 'VALARM') {
        inAlarm = false;
        final minutes = _triggerMinutes(trigger);
        if (minutes != null) reminders.add(minutes);
        continue;
      }
      if (prop.name == 'END' && prop.value == 'VEVENT') {
        final finished = props;
        if (finished != null) {
          final record = _toRecord(finished, reminders);
          if (record != null) {
            if (record.rrule == null && _first(finished, 'RRULE') != null) rulesSkipped++;
            records.add(record);
          }
        }
        props = null;
        continue;
      }

      final current = props;
      if (current == null) continue;
      if (inAlarm) {
        if (prop.name == 'TRIGGER') trigger = prop.value;
        continue;
      }
      current.add(prop);
    }

    return IcsReadResult(records, rulesSkipped);
  }

  static IcsRecord? _toRecord(List<IcsProperty> props, List<int> reminders) {
    final startProp = _first(props, 'DTSTART');
    if (startProp == null) return null;
    final startTime = _parseTime(startProp);
    final start = startTime.value;
    final allDay = startTime.allDay;

    final endProp = _first(props, 'DTEND');
    final end = endProp != null
        ? _parseTime(endProp).value
        : (allDay ? DateTime(start.year, start.month, start.day + 1) : start.add(const Duration(hours: 1)));

    final rawRule = _first(props, 'RRULE')?.value;
    String? rrule;
    if (rawRule != null) {
      try {
        RecurrenceRule.parse(rawRule);
        rrule = rawRule;
      } on FormatException {
        rrule = null;
      }
    }

    final exdates = <DateTime>[
      for (final p in _all(props, 'EXDATE'))
        for (final v in p.value.split(','))
          _parseTime(IcsProperty('EXDATE', p.params, v.trim())).value,
    ];

    final recurrenceProp = _first(props, 'RECURRENCE-ID');

    return IcsRecord(
      uid: _first(props, 'UID')?.value,
      calendarName: _text(_first(props, 'X-CHRONOSYNC-CALENDAR')?.value),
      title: _text(_first(props, 'SUMMARY')?.value) ?? '',
      location: _text(_first(props, 'LOCATION')?.value) ?? '',
      notes: _text(_first(props, 'DESCRIPTION')?.value) ?? '',
      allDay: allDay,
      start: start,
      end: end,
      rrule: rrule,
      recurrenceId: recurrenceProp == null ? null : _parseTime(recurrenceProp).value,
      exdates: exdates,
      reminders: reminders,
    );
  }

  static String? _text(String? raw) => raw == null ? null : IcsCodec.unescape(raw);

  static IcsProperty? _first(List<IcsProperty> props, String name) {
    for (final p in props) {
      if (p.name == name) return p;
    }
    return null;
  }

  static List<IcsProperty> _all(List<IcsProperty> props, String name) =>
      [for (final p in props) if (p.name == name) p];

  /// Reads a DATE, UTC date-time, zoned date-time (TZID) or floating date-time.
  static ({DateTime value, bool allDay}) _parseTime(IcsProperty p) {
    final v = p.value.trim();
    final y = int.parse(v.substring(0, 4));
    final mo = int.parse(v.substring(4, 6));
    final d = int.parse(v.substring(6, 8));

    if (p.params['VALUE'] == 'DATE' || v.length == 8) {
      return (value: DateTime(y, mo, d), allDay: true);
    }

    final h = int.parse(v.substring(9, 11));
    final mi = int.parse(v.substring(11, 13));
    final s = int.parse(v.substring(13, 15));

    if (v.endsWith('Z')) {
      return (value: DateTime.utc(y, mo, d, h, mi, s).toLocal(), allDay: false);
    }

    final tzid = p.params['TZID'];
    if (tzid != null) {
      try {
        final location = tz.getLocation(tzid);
        final zoned = tz.TZDateTime(location, y, mo, d, h, mi, s);
        return (value: DateTime.fromMillisecondsSinceEpoch(zoned.millisecondsSinceEpoch), allDay: false);
      } catch (_) {
        // Unknown zone name: fall back to the device time zone.
      }
    }
    return (value: DateTime(y, mo, d, h, mi, s), allDay: false);
  }

  /// "-PT15M" becomes 15. Only negative (before-start) triggers are used.
  static int? _triggerMinutes(String? trigger) {
    if (trigger == null) return null;
    final m = RegExp(r'^-P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$')
        .firstMatch(trigger.trim());
    if (m == null) return null;
    int g(int i) => int.tryParse(m.group(i) ?? '') ?? 0;
    return g(1) * 10080 + g(2) * 1440 + g(3) * 60 + g(4) + g(5) ~/ 60;
  }
}
