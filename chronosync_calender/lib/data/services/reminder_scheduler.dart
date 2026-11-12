import 'package:chronosync_calender/core/utils/app_format.dart';
import 'package:chronosync_calender/core/utils/date_helpers.dart';
import 'package:chronosync_calender/data/models/occurrence.dart';
import 'package:chronosync_calender/data/repositories/event_repository.dart';
import 'package:chronosync_calender/core/l10n/strings.dart';
import 'package:chronosync_calender/data/services/notification_service.dart';

/// Works out which reminders to schedule and hands them to the OS.
///
/// Only the next [horizonDays] are scheduled, capped at [maxPending]
/// (iOS allows at most 64 pending notifications). The schedule is refreshed
/// after every change and when the app starts.
abstract final class ReminderScheduler {
  static const horizonDays = 60;
  static const maxPending = 60;

  static Future<void> refresh(EventRepository events, Set<String> calendarIds) async {
    final now = DateTime.now();
    final occurrences = await events.occurrencesBetween(
      from: now,
      to: addDays(startOfDay(now), horizonDays),
      calendarIds: calendarIds,
    );

    final items = <ScheduledReminder>[];
    for (final occ in occurrences) {
      for (final minutes in occ.event.reminderMinutes) {
        final fireAt = _fireTime(occ, minutes);
        if (!fireAt.isAfter(now)) continue;
        items.add(
          ScheduledReminder(
            fireAt: fireAt,
            title: occ.event.title.isEmpty ? Strings.t('no_title') : occ.event.title,
            body: occ.isAllDay
                ? Strings.t('notif_all_day')
                : Strings.t('starts_at', {'time': AppFormat.time(occ.start)}),
            // "<eventId>|<occurrence start in ms>" so a tap can find the right occurrence.
            payload: '${occ.event.id}|${occ.originalStart.millisecondsSinceEpoch}',
          ),
        );
      }
    }

    items.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    await NotificationService.instance.replaceAll(items.take(maxPending).toList());
  }

  /// All-day events remind at 9:00 on their day, minus the lead time.
  static DateTime _fireTime(Occurrence occ, int minutes) {
    final base = occ.isAllDay
        ? DateTime(occ.start.year, occ.start.month, occ.start.day, 9)
        : occ.start;
    return base.subtract(Duration(minutes: minutes));
  }
}
