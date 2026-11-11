import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../state/calendar_controller.dart';
import 'home_shell.dart';

class ChronoSyncApp extends StatelessWidget {
  const ChronoSyncApp({super.key, required this.controller});

  final CalendarController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChronoSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: HomeShell(controller: controller),
    );
  }
}
