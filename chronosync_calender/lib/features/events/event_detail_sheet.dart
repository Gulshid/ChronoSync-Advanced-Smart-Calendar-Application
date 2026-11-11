import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/occurrence.dart';
import '../../state/calendar_controller.dart';
import '../calendar/widgets/event_tile.dart';
import 'event_actions.dart';

class EventDetailSheet extends StatelessWidget {
  const EventDetailSheet({
    super.key,
    required this.controller,
    required this.occurrence,
    required this.hostContext,
  });

  final CalendarController controller;
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
    final dateLine = DateFormat('EEEE, MMMM d, y').format(occurrence.start);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  calendarName,
                  style: theme.textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            event.title.isEmpty ? '(No title)' : event.title,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpace.lg),
          _InfoRow(icon: Icons.schedule, text: '$dateLine\n${timeRangeLabel(occurrence)}'),
          if (occurrence.isRecurring) const _InfoRow(icon: Icons.repeat, text: 'Part of a repeating series'),
          if (event.location.isNotEmpty) _InfoRow(icon: Icons.place_outlined, text: event.location),
          if (event.notes.isNotEmpty) _InfoRow(icon: Icons.notes_outlined, text: event.notes),
          const SizedBox(height: AppSpace.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _delete(context),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(foregroundColor: cs.error),
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
                  label: const Text('Edit'),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpace.md),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
