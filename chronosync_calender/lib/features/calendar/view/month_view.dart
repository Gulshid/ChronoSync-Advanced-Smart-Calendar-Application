import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:chronosync_calender/core/l10n/strings.dart';
import 'package:chronosync_calender/core/theme/app_theme.dart';
import 'package:chronosync_calender/core/utils/date_helpers.dart';
import 'package:chronosync_calender/data/models/occurrence.dart';
import 'package:chronosync_calender/features/calendar/view/event_tile.dart';
import 'package:chronosync_calender/features/calendar/view_model/calendar_view_model.dart';
import 'package:chronosync_calender/features/events/view/event_actions.dart';

/// Month grid. Tap a day to preview its events below; use "Open day" to go to the day view.
class MonthView extends StatefulWidget {
  const MonthView({super.key, required this.controller});

  final CalendarViewModel controller;

  @override
  State<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<MonthView> {
  late DateTime _selected = _initialSelection();

  /// Today when it is in the month on screen, otherwise the first focused day.
  DateTime _initialSelection() {
    final focus = widget.controller.focusDate;
    final now = DateTime.now();
    final inMonth = now.year == focus.year && now.month == focus.month;
    return startOfDay(inMonth ? now : focus);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final controller = widget.controller;
    final focus = controller.focusDate;
    final gridStart = startOfWeek(DateTime(focus.year, focus.month, 1), controller.firstWeekday);
    final weeks = [
      for (var w = 0; w < 6; w++) [for (var d = 0; d < 7; d++) addDays(gridStart, w * 7 + d)],
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                    child: Text(
                      DateFormat.E().format(addDays(gridStart, i)).toUpperCase(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
            child: Column(
              children: [
                for (final week in weeks)
                  Expanded(
                    child: Row(
                      children: [
                        for (final day in week)
                          Expanded(
                            child: _DayCell(
                              controller: controller,
                              day: day,
                              inMonth: day.month == focus.month,
                              selected: isSameDay(day, _selected),
                              occurrences: controller.occurrencesOn(day),
                              onTap: () => setState(() => _selected = startOfDay(day)),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          flex: 4,
          child: _DayPanel(controller: controller, day: _selected),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.controller,
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.occurrences,
    required this.onTap,
  });

  final CalendarViewModel controller;
  final DateTime day;
  final bool inMonth;
  final bool selected;
  final List<Occurrence> occurrences;
  final VoidCallback onTap;

  static const _numberRowHeight = 34.0;
  static const _chipHeight = 18.0;
  static const _maxChips = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final today = isToday(day);
    final border = cs.outlineVariant.withValues(alpha: 0.4);

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected && !today ? cs.primaryContainer.withValues(alpha: 0.35) : null,
          border: Border(right: BorderSide(color: border), bottom: BorderSide(color: border)),
        ),
        padding: const EdgeInsets.fromLTRB(3, 3, 3, 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Show only as many chips as fit, and reserve a line for "+N more" when needed.
            final room = ((constraints.maxHeight - _numberRowHeight) / _chipHeight).floor();
            final slots = clampInt(room, 0, _maxChips);
            final showCount = occurrences.length > slots ? clampInt(slots - 1, 0, _maxChips) : slots;
            final hidden = occurrences.length - showCount;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: _numberRowHeight - 6,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: today ? cs.primary : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${day.day}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: today
                              ? cs.onPrimary
                              : (inMonth ? cs.onSurface : cs.onSurface.withValues(alpha: 0.38)),
                          fontWeight: today || selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                for (final occ in occurrences.take(showCount))
                  _EventChip(occurrence: occ, color: eventColor(controller, occ.event)),
                if (hidden > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 1),
                    child: Text(
                      Strings.t('more_count', {'n': hidden}),
                      style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EventChip extends StatelessWidget {
  const _EventChip({required this.occurrence, required this.color});

  final Occurrence occurrence;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: _DayCell._chipHeight - 2,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.only(left: 4, right: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(width: 3, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              occurrence.event.title.isEmpty ? Strings.t('no_title') : occurrence.event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, height: 1.1, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Events for the selected day, shown under the month grid.
class _DayPanel extends StatelessWidget {
  const _DayPanel({required this.controller, required this.day});

  final CalendarViewModel controller;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final items = controller.occurrencesOn(day);
    final heading = isToday(day)
        ? '${Strings.t('today')} · ${DateFormat.MMMEd().format(day)}'
        : DateFormat.yMMMMEEEEd().format(day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.sm, AppSpace.xs),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(heading, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                    if (items.isNotEmpty)
                      Text(
                        Strings.t('events_count', {'n': items.length}),
                        style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => controller.openDay(day),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(Strings.t('open_day')),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    Strings.t('no_events_day'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpace.sm),
                  itemBuilder: (context, i) {
                    final occ = items[i];
                    return EventTile(
                      occurrence: occ,
                      color: eventColor(controller, occ.event),
                      calendarName: controller.calendarById(occ.event.calendarId)?.name ?? '',
                      onTap: () => openEventDetail(context, controller, occ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
