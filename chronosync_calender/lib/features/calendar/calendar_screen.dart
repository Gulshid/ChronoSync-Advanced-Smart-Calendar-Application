import 'package:flutter/material.dart';

import '../../core/utils/date_helpers.dart';
import '../../l10n/strings.dart';
import '../../state/calendar_controller.dart';
import '../quick_add/quick_add_sheet.dart';
import 'widgets/agenda_view.dart';
import 'widgets/calendar_header.dart';
import 'widgets/month_view.dart';
import 'widgets/time_grid.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key, required this.controller});

  final CalendarController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final focus = controller.focusDate;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                CalendarHeader(controller: controller),
                const Divider(height: 1),
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (velocity.abs() < 300) return;
                      controller.shift(velocity < 0 ? 1 : -1);
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: KeyedSubtree(
                        key: ValueKey('${controller.view.name}-${focus.year}-${focus.month}-${focus.day}'),
                        child: _buildView(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'calendar_fab',
            onPressed: () => openQuickAdd(context, controller),
            icon: const Icon(Icons.bolt),
            label: Text(Strings.t('new_event')),
          ),
        );
      },
    );
  }

  Widget _buildView() => switch (controller.view) {
        CalendarViewMode.month => MonthView(controller: controller),
        CalendarViewMode.agenda => AgendaView(controller: controller),
        CalendarViewMode.week => TimeGrid(controller: controller, days: _weekDays()),
        CalendarViewMode.day => TimeGrid(controller: controller, days: [startOfDay(controller.focusDate)]),
      };

  List<DateTime> _weekDays() {
    final start = startOfWeek(controller.focusDate, controller.firstWeekday);
    return [for (var i = 0; i < 7; i++) addDays(start, i)];
  }
}
