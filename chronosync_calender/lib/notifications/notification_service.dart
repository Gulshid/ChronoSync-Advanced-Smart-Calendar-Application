

class ScheduledReminder {
  const ScheduledReminder({
    required this.fireAt,
    required this.title,
    required this.body,
    required this.payload,
  });

  final DateTime fireAt;
  final String title;
  final String body;
  final String payload;
}

/// Wraps flutter_local_notifications. Works fully offline: notifications are stored by the OS.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  Future<void> init(void Function(String payload) onTap) async {
    if (_initialised) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: const DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onTap(payload);
      },
    );
    _initialised = true;
  }

  /// Payload of the notification that launched the app, if any.
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }

  Future<bool> requestPermissions() async {
    var granted = true;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      granted = await android.requestNotificationsPermission() ?? false;
      await android.requestExactAlarmsPermission();
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      granted = await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    return granted;
  }

  /// Replaces every pending reminder with [reminders]. Simple and always consistent.
  Future<void> replaceAll(List<ScheduledReminder> reminders) async {
    await _plugin.cancelAll();
    var id = 1;
    for (final r in reminders) {
      // Store the absolute instant in UTC, so the time is right whatever the device zone.
      final when = tz.TZDateTime.from(r.fireAt, tz.UTC);
      try {
        await _schedule(id, r, when, AndroidScheduleMode.exactAllowWhileIdle);
      } catch (_) {
        // Exact alarms can be disallowed on some Android versions. Fall back to inexact.
        await _schedule(id, r, when, AndroidScheduleMode.inexactAllowWhileIdle);
      }
      id++;
    }
  }

  Future<void> _schedule(int id, ScheduledReminder r, tz.TZDateTime when, AndroidScheduleMode mode) {
    return _plugin.zonedSchedule(
      id,
      r.title,
      r.body,
      when,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          Strings.t('notif_channel'),
          channelDescription: Strings.t('notif_channel_desc'),
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: r.payload,
    );
  }
}
