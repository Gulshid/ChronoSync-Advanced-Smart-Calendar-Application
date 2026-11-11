import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../state/calendar_controller.dart';

class CalendarHeader extends StatelessWidget {
  const CalendarHeader({super.key, required this.controller});

  final CalendarController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focus = controller.focusDate;
    final title = controller.view == CalendarViewMode.day
        ? DateFormat('EEEE, MMMM d').format(focus)
        : DateFormat('MMMM yyyy').format(focus);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.sm, AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(onPressed: controller.goToday, child: const Text('Today')),
              IconButton(
                tooltip: 'Previous',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => controller.shift(-1),
              ),
              IconButton(
                tooltip: 'Next',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => controller.shift(1),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          SegmentedButton<CalendarViewMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: CalendarViewMode.day, label: Text('Day')),
              ButtonSegment(value: CalendarViewMode.week, label: Text('Week')),
              ButtonSegment(value: CalendarViewMode.month, label: Text('Month')),
              ButtonSegment(value: CalendarViewMode.agenda, label: Text('Agenda')),
            ],
            selected: {controller.view},
            onSelectionChanged: (selection) => controller.setView(selection.first),
          ),
        ],
      ),
    );
  }
}
