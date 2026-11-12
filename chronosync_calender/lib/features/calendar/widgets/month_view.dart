import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../l10n/strings.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../data/models/occurrence.dart';
import '../../../state/calendar_controller.dart';
import 'event_tile.dart';

class MonthView extends StatelessWidget {
  const MonthView({super.key, required this.controller});

  final CalendarController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final focus = controller.focusDate;
    final gridStart = startOfWeek(DateTime(focus.year, focus.month, 1), controller.firstWeekday);
    final weeks = [
      for (var w = 0; w < 6; w++) [for (var d = 0; d < 7; d++) addDays(gridStart, w * 7 + d)],
    ];

    return Column(
      children: [
        Row(
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
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        Expanded(
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
                            occurrences: controller.occurrencesOn(day),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
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
    required this.occurrences,
  });

  final CalendarController controller;
  final DateTime day;
  final bool inMonth;
  final List<Occurrence> occurrences;

  static const _numberRowHeight = 34.0;
  static const _chipHeight = 18.0;
  static const _maxChips = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final today = isToday(day);
    final border = cs.outlineVariant.withValues(alpha: 0.5);

    return InkWell(
      onTap: () => controller.openDay(day),
      child: Container(
        decoration: BoxDecoration(
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
                          fontWeight: today ? FontWeight.w700 : FontWeight.w500,
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
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(width: 3, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              occurrence.event.title.isEmpty ? '(No title)' : occurrence.event.title,
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
