/// Calendar arithmetic on wall-clock dates.
///
/// Build dates with DateTime(y, m, d + n, h, min) rather than adding a Duration.
/// This keeps the local time of day steady across daylight-saving changes.
DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days, d.hour, d.minute);

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

bool isToday(DateTime d) => isSameDay(d, DateTime.now());

/// First day of the week containing [d]. [firstWeekday] uses DateTime.monday (1) to DateTime.sunday (7).
DateTime startOfWeek(DateTime d, int firstWeekday) {
  final offset = (d.weekday - firstWeekday + 7) % 7;
  return startOfDay(addDays(d, -offset));
}

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Number of calendar days from [start] to [end] (ignores time of day and DST).
int calendarDaysBetween(DateTime start, DateTime end) =>
    DateTime.utc(end.year, end.month, end.day)
        .difference(DateTime.utc(start.year, start.month, start.day))
        .inDays;

int clampInt(int value, int min, int max) => value < min ? min : (value > max ? max : value);
