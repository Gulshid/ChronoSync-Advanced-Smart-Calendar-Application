import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:chronosync_calender/core/l10n/strings.dart';
import 'package:chronosync_calender/core/theme/app_theme.dart';
import 'package:chronosync_calender/core/utils/date_helpers.dart';
import 'package:chronosync_calender/features/calendar/view_model/calendar_view_model.dart';
import 'package:chronosync_calender/features/free_time/view/free_time_sheet.dart';
import 'package:chronosync_calender/features/search/view/search_screen.dart';

/// Top bar of the calendar: period title (tap to jump to a date), prev/next, and the view switcher.
class CalendarHeader extends StatelessWidget {
  const CalendarHeader({super.key, required this.controller});

  final CalendarViewModel controller;

  String _title() {
    final focus = controller.focusDate;
    return switch (controller.view) {
      CalendarViewMode.day => DateFormat('EEEE, MMM d').format(focus),
      CalendarViewMode.week => _weekTitle(),
      CalendarViewMode.month || CalendarViewMode.agenda => DateFormat('MMMM yyyy').format(focus),
    };
  }

  /// "Nov 9 – 15, 2026" or "Nov 29 – Dec 5, 2026".
  String _weekTitle() {
    final start = startOfWeek(controller.focusDate, controller.firstWeekday);
    final end = addDays(start, 6);
    final endText = start.month == end.month
        ? DateFormat('d, y').format(end)
        : DateFormat('MMM d, y').format(end);
    return '${DateFormat('MMM d').format(start)} – $endText';
  }

  /// True when today falls inside the period on screen, so the Today button can be hidden.
  bool _isCurrentPeriod() {
    final now = DateTime.now();
    final focus = controller.focusDate;
    return switch (controller.view) {
      CalendarViewMode.day || CalendarViewMode.agenda => isSameDay(focus, now),
      CalendarViewMode.month => focus.year == now.year && focus.month == now.month,
      CalendarViewMode.week => _inCurrentWeek(now),
    };
  }

  bool _inCurrentWeek(DateTime now) {
    final start = startOfWeek(controller.focusDate, controller.firstWeekday);
    return !now.isBefore(start) && now.isBefore(addDays(start, 7));
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.focusDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: Strings.t('jump_to_date'),
    );
    if (picked != null) controller.jumpTo(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.sm, AppSpace.sm, AppSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: Strings.t('previous'),
                icon: const Icon(Icons.chevron_left),
                onPressed: () => controller.shift(-1),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => _pickDate(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _title(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, color: cs.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: Strings.t('next'),
                icon: const Icon(Icons.chevron_right),
                onPressed: () => controller.shift(1),
              ),
              if (!_isCurrentPeriod())
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: Strings.t('today'),
                  icon: const Icon(Icons.today_outlined),
                  onPressed: controller.goToday,
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: Strings.t('search'),
                icon: const Icon(Icons.search),
                onPressed: () => openSearch(context, controller),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<CalendarViewMode>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
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
                visualDensity: VisualDensity.compact,
                tooltip: Strings.t('free_time'),
                icon: const Icon(Icons.event_available_outlined),
                onPressed: () => openFreeTime(context, controller),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
