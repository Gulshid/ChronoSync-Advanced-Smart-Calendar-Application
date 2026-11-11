import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../state/calendar_controller.dart';
import '../../events/event_actions.dart';
import 'event_tile.dart';

class AgendaView extends StatelessWidget {
  const AgendaView({super.key, required this.controller});

  final CalendarController controller;

  static const _days = 30;

  @override
  Widget build(BuildContext context) {
    final start = startOfDay(controller.focusDate);
    final children = <Widget>[];

    for (var i = 0; i < _days; i++) {
      final day = addDays(start, i);
      final items = controller.occurrencesOn(day);
      if (items.isEmpty) continue;

      children.add(_AgendaDayHeader(day: day));
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
      return const EmptyState(
        icon: Icons.event_available_outlined,
        title: 'Nothing planned',
        message: 'No events in the next 30 days. Tap New event to add one.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, 96),
      children: children,
    );
  }
}

class _AgendaDayHeader extends StatelessWidget {
  const _AgendaDayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = isToday(day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppSpace.md, 4, AppSpace.sm),
      child: Row(
        children: [
          Text(
            today ? 'Today' : DateFormat('EEEE, MMM d').format(day),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: today ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
