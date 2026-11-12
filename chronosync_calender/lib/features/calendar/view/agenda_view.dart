import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:chronosync_calender/core/l10n/strings.dart';
import 'package:chronosync_calender/core/theme/app_theme.dart';
import 'package:chronosync_calender/core/utils/date_helpers.dart';
import 'package:chronosync_calender/core/widgets/empty_state.dart';
import 'package:chronosync_calender/features/calendar/view/event_tile.dart';
import 'package:chronosync_calender/features/calendar/view_model/calendar_view_model.dart';
import 'package:chronosync_calender/features/events/view/event_actions.dart';
import 'package:chronosync_calender/features/quick_add/view/quick_add_sheet.dart';

/// Chronological list of the next 30 days, grouped by day. Empty days are skipped.
class AgendaView extends StatelessWidget {
  const AgendaView({super.key, required this.controller});

  final CalendarViewModel controller;

  static const _days = 30;

  @override
  Widget build(BuildContext context) {
    final start = startOfDay(controller.focusDate);
    final children = <Widget>[];

    for (var i = 0; i < _days; i++) {
      final day = addDays(start, i);
      final items = controller.occurrencesOn(day);
      if (items.isEmpty) continue;

      children.add(_AgendaDayHeader(day: day, count: items.length));
      for (final occ in items) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: EventTile(
              occurrence: occ,
              color: eventColor(controller, occ.event),
              calendarName: controller.calendarById(occ.event.calendarId)?.name ?? '',
              onTap: () => openEventDetail(context, controller, occ),
            ),
          ),
        );
      }
    }

    if (children.isEmpty) {
      return EmptyState(
        icon: Icons.event_available_outlined,
        title: Strings.t('nothing_planned'),
        message: Strings.t('nothing_planned_msg'),
        action: FilledButton.icon(
          onPressed: () => openQuickAdd(context, controller),
          icon: const Icon(Icons.bolt),
          label: Text(Strings.t('new_event')),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, 96),
      children: children,
    );
  }
}

class _AgendaDayHeader extends StatelessWidget {
  const _AgendaDayHeader({required this.day, required this.count});

  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final today = isToday(day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.lg, AppSpace.xs, AppSpace.sm),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: today ? cs.primary : cs.outline, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              today ? '${Strings.t('today')} · ${DateFormat.MMMEd().format(day)}' : DateFormat('EEEE, MMM d').format(day),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: today ? cs.primary : cs.onSurface,
              ),
            ),
          ),
          Text(
            Strings.t('events_count', {'n': count}),
            style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
