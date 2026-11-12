import 'package:flutter/material.dart';

import 'package:chronosync_calender/core/l10n/strings.dart';
import 'package:chronosync_calender/features/calendar/view/calendar_screen.dart';
import 'package:chronosync_calender/features/calendar/view_model/calendar_view_model.dart';
import 'package:chronosync_calender/features/calendars/view/calendars_screen.dart';
import 'package:chronosync_calender/features/settings/view/settings_screen.dart';

/// Top-level scaffold. Uses a bottom bar on phones and a side rail on wide screens.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final CalendarViewModel controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _wideBreakpoint = 840.0;
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = IndexedStack(
      index: _index,
      children: [
        CalendarScreen(controller: widget.controller),
        CalendarsScreen(controller: widget.controller),
        const SettingsScreen(),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _wideBreakpoint) {
          return Scaffold(
            body: Row(
              children: [
                SafeArea(
                  right: false,
                  child: NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: (i) => setState(() => _index = i),
                    destinations: [
                      NavigationRailDestination(
                        icon: const Icon(Icons.calendar_month_outlined),
                        selectedIcon: const Icon(Icons.calendar_month),
                        label: Text(Strings.t('nav_calendar')),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.layers_outlined),
                        selectedIcon: const Icon(Icons.layers),
                        label: Text(Strings.t('nav_calendars')),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.settings_outlined),
                        selectedIcon: const Icon(Icons.settings),
                        label: Text(Strings.t('nav_settings')),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages),
              ],
            ),
          );
        }

        return Scaffold(
          body: pages,
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
      },
    );
  }
}
