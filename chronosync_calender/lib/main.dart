import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'data/database/app_database.dart';
import 'data/repositories/calendar_repository.dart';
import 'data/repositories/event_repository.dart';
import 'notifications/notification_service.dart';
import 'notifications/reminder_router.dart';
import 'notifications/reminder_scheduler.dart';
import 'state/app_settings.dart';
import 'state/calendar_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await AppSettings.instance.load();

  final db = await AppDatabase.open();
  final events = EventRepository(db);
  final controller = CalendarController(events: events, calendars: CalendarRepository(db));

  controller.onDataChanged = (calendarIds) => ReminderScheduler.refresh(events, calendarIds);
  await NotificationService.instance.init((payload) => openReminder(payload, events, controller));
  await controller.init();

  runApp(ChronoSyncApp(controller: controller));

  // Ask for permission once the first frame is up, and open the event if a reminder launched the app.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await NotificationService.instance.requestPermissions();
    final launch = await NotificationService.instance.launchPayload();
    if (launch != null) await openReminder(launch, events, controller);
  });
}
