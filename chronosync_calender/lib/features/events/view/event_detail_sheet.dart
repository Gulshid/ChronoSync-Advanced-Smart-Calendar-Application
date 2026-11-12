import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:chronosync_calender/core/l10n/strings.dart';
import 'package:chronosync_calender/core/theme/app_theme.dart';
import 'package:chronosync_calender/core/widgets/app_section.dart';
import 'package:chronosync_calender/data/models/occurrence.dart';
import 'package:chronosync_calender/features/calendar/view/event_tile.dart';
import 'package:chronosync_calender/features/calendar/view_model/calendar_view_model.dart';
import 'package:chronosync_calender/features/events/view/event_actions.dart';

/// Read-only summary of an event with Edit and Delete actions.
class EventDetailSheet extends StatelessWidget {
  const EventDetailSheet({
    super.key,
    required this.controller,
    required this.occurrence,
    required this.hostContext,
  });

  final CalendarViewModel controller;
  final Occurrence occurrence;

  /// The screen context. Used after this sheet closes.
  final BuildContext hostContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final event = occurrence.event;
    final color = eventColor(controller, event);
    final calendarName = controller.calendarById(event.calendarId)?.name ?? '';
    final dateLine = DateFormat.yMMMMEEEEd().format(occurrence.start);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: AppSpace.sm),
                Flexible(
                  child: Text(
                    calendarName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(color: cs.onSurface),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            event.title.isEmpty ? Strings.t('no_title') : event.title,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpace.xl),
          _InfoRow(icon: Icons.schedule, text: '$dateLine\n${timeRangeLabel(occurrence)}'),
          if (occurrence.isRecurring) _InfoRow(icon: Icons.repeat, text: Strings.t('repeating')),
          if (event.reminderMinutes.isNotEmpty)
            _InfoRow(
              icon: Icons.notifications_outlined,
              text: event.reminderMinutes.map(Strings.leadLabel).join(', '),
            ),
          if (event.location.isNotEmpty) _InfoRow(icon: Icons.place_outlined, text: event.location),
          if (event.notes.isNotEmpty) _InfoRow(icon: Icons.notes_outlined, text: event.notes),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _delete(context),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(Strings.t('delete')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.error,
                    side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    openEventEditor(hostContext, controller, occurrence: occurrence);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(Strings.t('edit')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext sheetContext) async {
    final messenger = ScaffoldMessenger.of(hostContext);
    Navigator.pop(sheetContext);
    final undo = await promptAndDelete(hostContext, controller, occurrence);
    if (undo != null) showUndoSnack(messenger, controller, undo);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconBadge(icon: icon, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpace.md),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
