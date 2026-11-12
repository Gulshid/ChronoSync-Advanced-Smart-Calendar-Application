import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:chronosync_calender/core/app/app.dart';
import 'package:chronosync_calender/core/app/app_services.dart';
import 'package:chronosync_calender/data/repositories/app_database.dart';
import 'package:chronosync_calender/data/repositories/calendar_repository.dart';
import 'package:chronosync_calender/data/repositories/event_repository.dart';
import 'package:chronosync_calender/data/repositories/transfer_repository.dart';
import 'package:chronosync_calender/data/services/notification_service.dart';
import 'package:chronosync_calender/core/app/reminder_router.dart';
import 'package:chronosync_calender/data/services/reminder_scheduler.dart';
import 'package:chronosync_calender/data/services/app_settings.dart';
import 'package:chronosync_calender/features/calendar/view_model/calendar_view_model.dart';
import 'package:chronosync_calender/data/services/google_calendar_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await AppSettings.instance.load();

  final db = await AppDatabase.open();
  final events = EventRepository(db);
  final transfer = TransferRepository(db);
  final controller = CalendarViewModel(events: events, calendars: CalendarRepository(db));

  AppServices.controller = controller;
  AppServices.transfer = transfer;

  controller.onDataChanged = (calendarIds) async {
    await ReminderScheduler.refresh(events, calendarIds);
    GoogleCalendarSync.instance.scheduleAutoSync(transfer, () async {
      await controller.reload();
      await ReminderScheduler.refresh(events, controller.visibleCalendarIds);
    });
  };

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
