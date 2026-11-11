import 'package:flutter/material.dart';

import '../features/calendar/calendar_screen.dart';
import '../features/calendars/calendars_screen.dart';
import '../state/calendar_controller.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final CalendarController controller;

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
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.layers_outlined),
            selectedIcon: Icon(Icons.layers),
            label: 'Calendars',
          ),
        ],
      ),
    );
  }
}
