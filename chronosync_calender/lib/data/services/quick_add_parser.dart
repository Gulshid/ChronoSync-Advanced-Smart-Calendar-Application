import 'package:chronosync_calender/core/utils/date_helpers.dart';

class QuickAddResult {
  const QuickAddResult({required this.title, required this.start, required this.end, required this.allDay});

  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
}

/// Reads phrases such as "Lunch with Sara tomorrow 1pm" into an event.
///
/// Understands: today, tonight, tomorrow, day after tomorrow, in N days,
/// weekday names (with "next"), "12 Dec", "Dec 12", times like 3pm, 3:30 pm,
/// 15:00, noon, midnight, "at 9", "all day", and durations like "for 45 minutes".
/// Whatever is not a date, time or duration becomes the title.
abstract final class QuickAddParser {
  static const _weekdays = {
    'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4,
    'friday': 5, 'saturday': 6, 'sunday': 7,
  };

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static QuickAddResult parse(String input, {required DateTime now}) {
    final lower = input.toLowerCase();
    // Characters already used by a matched phrase. They are hidden from later patterns and removed from the title.
    final mask = List<bool>.filled(lower.length, false);

    String visible() {
      final buffer = StringBuffer();
      for (var i = 0; i < lower.length; i++) {
        buffer.write(mask[i] ? ' ' : lower[i]);
      }
      return buffer.toString();
    }

    RegExpMatch? take(RegExp pattern) {
      final match = pattern.firstMatch(visible());
      if (match == null) return null;
      for (var i = match.start; i < match.end; i++) {
        mask[i] = true;
      }
      return match;
    }

    final allDay = take(RegExp(r'\ball\s*day\b')) != null;

    int? durationMinutes;
    final hours = take(RegExp(r'\bfor\s+(\d+)\s*(hours?|hrs?|h)\b'));
    if (hours != null) durationMinutes = int.parse(hours.group(1)!) * 60;
    final minutes = take(RegExp(r'\bfor\s+(\d+)\s*(minutes?|mins?|m)\b'));
    if (minutes != null) durationMinutes = int.parse(minutes.group(1)!);

    // Time of day
    int? hour;
    var minute = 0;
    final ampm = take(RegExp(r'\b(?:at\s+)?(\d{1,2})(?::([0-5]\d))?\s*(am|pm|a\.m\.|p\.m\.)(?![a-z])'));
    if (ampm != null) {
      var h = int.parse(ampm.group(1)!) % 12;
      if (ampm.group(3)!.startsWith('p')) h += 12;
      hour = h;
      minute = ampm.group(2) == null ? 0 : int.parse(ampm.group(2)!);
    }
    if (hour == null) {
      final h24 = take(RegExp(r'\b(?:at\s+)?([01]?\d|2[0-3]):([0-5]\d)\b'));
      if (h24 != null) {
        hour = int.parse(h24.group(1)!);
        minute = int.parse(h24.group(2)!);
      }
    }
    if (hour == null) {
      // "at 9" with no am/pm: 1 to 6 means afternoon, 7 to 11 means morning.
      final bare = take(RegExp(r'\bat\s+(\d{1,2})\b'));
      if (bare != null) {
        final h = int.parse(bare.group(1)!);
        hour = (h >= 1 && h <= 6) ? h + 12 : h;
      }
    }
    final noon = take(RegExp(r'\b(noon|midnight)\b'));
    if (noon != null && hour == null) {
      hour = noon.group(1) == 'noon' ? 12 : 0;
      minute = 0;
    }
    final tonight = take(RegExp(r'\btonight\b'));
    if (tonight != null && hour == null) hour = 19;

    // Date
    final today = startOfDay(now);
    DateTime? date;
    if (take(RegExp(r'\bday after tomorrow\b')) != null) {
      date = addDays(today, 2);
    } else if (take(RegExp(r'\btomorrow\b')) != null) {
      date = addDays(today, 1);
    } else if (take(RegExp(r'\btoday\b')) != null || tonight != null) {
      date = today;
    }

    final inDays = take(RegExp(r'\bin\s+(\d+)\s+days?\b'));
    if (inDays != null) date = addDays(today, int.parse(inDays.group(1)!));

    if (date == null) {
      final weekday = take(RegExp(r'\b(next\s+|this\s+|on\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b'));
      if (weekday != null) {
        final target = _weekdays[weekday.group(2)]!;
        var diff = (target - now.weekday + 7) % 7;
        // "next Monday" said on a Monday means a week from today.
        if ((weekday.group(1) ?? '').trim() == 'next' && diff == 0) diff = 7;
        date = addDays(today, diff);
      }
    }
    if (date == null) {
      final dayFirst = take(RegExp(r'\b(\d{1,2})(?:st|nd|rd|th)?\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\b'));
      if (dayFirst != null) {
        date = _nextMonthDay(_months[dayFirst.group(2)]!, int.parse(dayFirst.group(1)!), today);
      }
    }
    if (date == null) {
      final monthFirst = take(RegExp(r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+(\d{1,2})(?:st|nd|rd|th)?\b'));
      if (monthFirst != null) {
        date = _nextMonthDay(_months[monthFirst.group(1)!]!, int.parse(monthFirst.group(2)!), today);
      }
    }

    final title = _title(input, lower, mask, fallback: input.trim());

    if (allDay) {
      final day = startOfDay(date ?? today);
      return QuickAddResult(title: title, start: day, end: addDays(day, 1), allDay: true);
    }

    DateTime start;
    if (date == null && hour == null) {
      start = DateTime(now.year, now.month, now.day, now.hour + 1);
    } else if (date == null) {
      start = DateTime(now.year, now.month, now.day, hour!, minute);
      if (!start.isAfter(now)) start = addDays(start, 1);
    } else {
      start = DateTime(date.year, date.month, date.day, hour ?? 9, hour == null ? 0 : minute);
    }

    return QuickAddResult(
      title: title,
      start: start,
      end: start.add(Duration(minutes: durationMinutes ?? 60)),
      allDay: false,
    );
  }

  static DateTime _nextMonthDay(int month, int day, DateTime today) {
    final candidate = DateTime(today.year, month, day);
    return candidate.isBefore(today) ? DateTime(today.year + 1, month, day) : candidate;
  }

  static String _title(String input, String lower, List<bool> mask, {required String fallback}) {
    final source = input.length == lower.length ? input : lower;
    final buffer = StringBuffer();
    for (var i = 0; i < source.length; i++) {
      if (!mask[i]) buffer.write(source[i]);
    }
    var title = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    title = title.replaceAll(RegExp(r'^[\s,.\-–—:@]+|[\s,.\-–—:@]+$'), '');
    title = title
        .replaceAll(RegExp(r'^(at|on|for|by|from)\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+(at|on|for|by|from)$', caseSensitive: false), '')
        .trim();
    return title.isEmpty ? fallback : title;
  }
}
