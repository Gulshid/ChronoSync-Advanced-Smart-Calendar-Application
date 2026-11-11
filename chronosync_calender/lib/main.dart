import 'package:flutter/material.dart';

import 'app/app.dart';
import 'data/database/app_database.dart';
import 'data/repositories/calendar_repository.dart';
import 'data/repositories/event_repository.dart';
import 'state/calendar_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.open();
  final controller = CalendarController(
    events: EventRepository(db),
    calendars: CalendarRepository(db),
  );
  await controller.init();
  runApp(ChronoSyncApp(controller: controller));
}
