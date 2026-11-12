import 'package:intl/intl.dart';

/// Time formatting that follows the 12/24-hour setting.
abstract final class AppFormat {
  static bool use24Hour = false;

  static String time(DateTime t) => DateFormat(use24Hour ? 'HH:mm' : 'h:mm a').format(t);

  static String hour(int h) => DateFormat(use24Hour ? 'HH:mm' : 'h a').format(DateTime(2000, 1, 1, h));

  static String range(DateTime start, DateTime end) => '${time(start)} – ${time(end)}';
}
