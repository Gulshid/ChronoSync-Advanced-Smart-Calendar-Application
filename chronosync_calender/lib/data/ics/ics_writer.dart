import '../models/event_model.dart';
import 'ics_codec.dart';

/// Writes events as an .ics file that Google Calendar, Outlook and Apple Calendar can open.
///
/// Series become one VEVENT with RRULE. Cancelled occurrences become EXDATE lines.
/// Moved occurrences become VEVENTs with RECURRENCE-ID. Reminders become VALARM blocks.
abstract final class IcsWriter {
  static String build({
    required List<EventModel> events,
    required Map<String, String> calendarNames,
  }) {
    final byId = {for (final e in events) e.id: e};

    // Cancelled occurrences become EXDATE lines on their series master.
    final exdates = <String, List<String>>{};
    for (final e in events) {
      final parent = e.parentId;
      final original = e.originalStart;
      if (parent != null && e.isCancelled && original != null) {
        exdates.putIfAbsent(parent, () => []).add(_dateLine('EXDATE', original, e.allDay));
      }
    }

    final stamp = _utc(DateTime.now());
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//ChronoSync//Flutter//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
    ];

    for (final e in events) {
      if (e.isCancelled) continue;
      final parentId = e.parentId;
      final master = parentId == null ? e : byId[parentId];
      if (master == null) continue;

      // Every occurrence of a series shares the master's UID.
      final uid = '${master.id}@chronosync';
      final calName = calendarNames[e.calendarId] ?? 'Personal';

      lines.add('BEGIN:VEVENT');
      lines.add('UID:$uid');
      lines.add('DTSTAMP:$stamp');
      if (parentId != null) {
        lines.add(_dateLine('RECURRENCE-ID', e.originalStart ?? e.start, e.allDay));
      }
      lines.add(_dateLine('DTSTART', e.start, e.allDay));
      lines.add(_dateLine('DTEND', e.end, e.allDay));
      if (parentId == null && e.rrule != null) lines.add('RRULE:${e.rrule}');
      if (parentId == null) lines.addAll(exdates[e.id] ?? const []);
      lines.add('SUMMARY:${IcsCodec.escape(e.title)}');
      if (e.location.isNotEmpty) lines.add('LOCATION:${IcsCodec.escape(e.location)}');
      if (e.notes.isNotEmpty) lines.add('DESCRIPTION:${IcsCodec.escape(e.notes)}');
      lines.add('X-CHRONOSYNC-CALENDAR:${IcsCodec.escape(calName)}');
      for (final minutes in e.reminderMinutes) {
        lines.add('BEGIN:VALARM');
        lines.add('ACTION:DISPLAY');
        lines.add('DESCRIPTION:Reminder');
        lines.add('TRIGGER:${minutes == 0 ? 'PT0S' : '-PT${minutes}M'}');
        lines.add('END:VALARM');
      }
      lines.add('END:VEVENT');
    }

    lines.add('END:VCALENDAR');
    return '${lines.map(IcsCodec.fold).join('\r\n')}\r\n';
  }

  static String _p(int value, [int width = 2]) => value.toString().padLeft(width, '0');

  static String _utc(DateTime d) {
    final u = d.toUtc();
    return '${_p(u.year, 4)}${_p(u.month)}${_p(u.day)}T${_p(u.hour)}${_p(u.minute)}${_p(u.second)}Z';
  }

  static String _date(DateTime d) => '${_p(d.year, 4)}${_p(d.month)}${_p(d.day)}';

  static String _dateLine(String name, DateTime d, bool allDay) =>
      allDay ? '$name;VALUE=DATE:${_date(d)}' : '$name:${_utc(d)}';
}
