enum RecurFrequency { daily, weekly, monthly, yearly }

/// The RFC 5545 subset ChronoSync supports.
///
/// Supported parts: FREQ, INTERVAL, BYDAY (weekly), BYMONTHDAY (monthly), COUNT, UNTIL.
class RecurrenceRule {
  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.weekdays = const [],
    this.monthDay,
    this.count,
    this.until,
  });

  final RecurFrequency frequency;
  final int interval;

  /// DateTime.monday (1) to DateTime.sunday (7). Used by weekly rules.
  final List<int> weekdays;

  /// Day of month (1 to 31). Null means the same day as the start.
  final int? monthDay;
  final int? count;

  /// Inclusive end, stored as a UTC instant.
  final DateTime? until;

  static const _codes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  factory RecurrenceRule.parse(String raw) {
    final parts = <String, String>{};
    for (final segment in raw.split(';')) {
      final eq = segment.indexOf('=');
      if (eq <= 0) continue;
      parts[segment.substring(0, eq).trim().toUpperCase()] = segment.substring(eq + 1).trim();
    }

    final frequency = switch (parts['FREQ']) {
      'DAILY' => RecurFrequency.daily,
      'WEEKLY' => RecurFrequency.weekly,
      'MONTHLY' => RecurFrequency.monthly,
      'YEARLY' => RecurFrequency.yearly,
      _ => throw FormatException('Unsupported or missing FREQ in "$raw"'),
    };

    final interval = int.tryParse(parts['INTERVAL'] ?? '1') ?? 1;
    if (interval < 1) throw FormatException('INTERVAL must be at least 1 in "$raw"');

    final weekdays = <int>[];
    for (final code in (parts['BYDAY'] ?? '').split(',')) {
      final token = code.trim().toUpperCase();
      if (token.isEmpty) continue;
      final index = _codes.indexOf(token);
      if (index < 0) throw FormatException('Unsupported BYDAY value "$token"');
      weekdays.add(index + 1);
    }
    weekdays.sort();

    return RecurrenceRule(
      frequency: frequency,
      interval: interval,
      weekdays: weekdays,
      monthDay: parts['BYMONTHDAY'] == null ? null : int.parse(parts['BYMONTHDAY']!),
      count: parts['COUNT'] == null ? null : int.parse(parts['COUNT']!),
      until: parts['UNTIL'] == null ? null : _parseUntil(parts['UNTIL']!),
    );
  }

  String toRRule() {
    final b = StringBuffer('FREQ=${frequency.name.toUpperCase()}');
    if (interval != 1) b.write(';INTERVAL=$interval');
    if (weekdays.isNotEmpty) b.write(';BYDAY=${weekdays.map((d) => _codes[d - 1]).join(',')}');
    if (monthDay != null) b.write(';BYMONTHDAY=$monthDay');
    if (count != null) b.write(';COUNT=$count');
    if (until != null) b.write(';UNTIL=${_formatUtc(until!)}');
    return b.toString();
  }

  RecurrenceRule copyWith({int? count, DateTime? until, bool clearCount = false, bool clearUntil = false}) {
    return RecurrenceRule(
      frequency: frequency,
      interval: interval,
      weekdays: weekdays,
      monthDay: monthDay,
      count: clearCount ? null : (count ?? this.count),
      until: clearUntil ? null : (until ?? this.until),
    );
  }

  static DateTime _parseUntil(String value) {
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$').firstMatch(value);
    if (m == null) throw FormatException('Bad UNTIL value "$value"');
    final y = int.parse(m[1]!);
    final mo = int.parse(m[2]!);
    final d = int.parse(m[3]!);
    if (m[4] == null) return DateTime(y, mo, d, 23, 59, 59).toUtc();
    final h = int.parse(m[4]!);
    final mi = int.parse(m[5]!);
    final s = int.parse(m[6]!);
    return m[7] == 'Z' ? DateTime.utc(y, mo, d, h, mi, s) : DateTime(y, mo, d, h, mi, s).toUtc();
  }

  static String _formatUtc(DateTime value) {
    final u = value.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${u.year.toString().padLeft(4, '0')}${two(u.month)}${two(u.day)}'
        'T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  }
}
