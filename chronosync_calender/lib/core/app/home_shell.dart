import 'package:flutter/material.dart';

import 'package:chronosync_calender/features/calendar/view/calendar_screen.dart';
import 'package:chronosync_calender/features/calendars/view/calendars_screen.dart';
import 'package:chronosync_calender/features/settings/view/settings_screen.dart';
import 'package:chronosync_calender/core/l10n/strings.dart';
import 'package:chronosync_calender/features/calendar/view_model/calendar_view_model.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final CalendarViewModel controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          CalendarScreen(controller: widget.controller),
          CalendarsScreen(controller: widget.controller),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: Strings.t('nav_calendar'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.layers_outlined),
            selectedIcon: const Icon(Icons.layers),
            label: Strings.t('nav_calendars'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: Strings.t('nav_settings'),
          ),
        ],
      ),
    );
  }
}
