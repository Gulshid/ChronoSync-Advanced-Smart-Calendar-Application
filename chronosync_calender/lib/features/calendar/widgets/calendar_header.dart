import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/strings.dart';
import '../../../state/calendar_controller.dart';
import '../../free_time/free_time_sheet.dart';
import '../../search/search_screen.dart';

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
              TextButton(onPressed: controller.goToday, child: Text(Strings.t('today'))),
              IconButton(
                tooltip: Strings.t('previous'),
                icon: const Icon(Icons.chevron_left),
                onPressed: () => controller.shift(-1),
              ),
              IconButton(
                tooltip: Strings.t('next'),
                icon: const Icon(Icons.chevron_right),
                onPressed: () => controller.shift(1),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<CalendarViewMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: CalendarViewMode.day, label: Text(Strings.t('view_day'))),
                    ButtonSegment(value: CalendarViewMode.week, label: Text(Strings.t('view_week'))),
                    ButtonSegment(value: CalendarViewMode.month, label: Text(Strings.t('view_month'))),
                    ButtonSegment(value: CalendarViewMode.agenda, label: Text(Strings.t('view_agenda'))),
                  ],
                  selected: {controller.view},
                  onSelectionChanged: (selection) => controller.setView(selection.first),
                ),
              ),
              IconButton(
                tooltip: Strings.t('search'),
                icon: const Icon(Icons.search),
                onPressed: () => openSearch(context, controller),
              ),
              IconButton(
                tooltip: Strings.t('free_time'),
                icon: const Icon(Icons.hourglass_empty),
                onPressed: () => openFreeTime(context, controller),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
