import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/calendar_model.dart';
import '../../state/calendar_controller.dart';
import 'calendar_editor_sheet.dart';

class CalendarsScreen extends StatelessWidget {
  const CalendarsScreen({super.key, required this.controller});

  final CalendarController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final calendars = controller.calendars;

        return Scaffold(
          appBar: AppBar(title: const Text('Calendars')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, 96),
            children: [
              Text(
                'Hidden calendars stay saved. Their events just stop showing.',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpace.lg),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < calendars.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 56),
                      _CalendarRow(controller: controller, calendar: calendars[i]),
                    ],
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _create(context),
            icon: const Icon(Icons.add),
            label: const Text('New calendar'),
          ),
        );
      },
    );
  }

  Future<void> _create(BuildContext context) async {
    final result = await showModalBottomSheet<CalendarModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CalendarEditorSheet(nextSortOrder: controller.calendars.length),
    );
    if (result != null) await controller.saveCalendar(result);
  }
}

class _CalendarRow extends StatelessWidget {
  const _CalendarRow({required this.controller, required this.calendar});

  final CalendarController controller;
  final CalendarModel calendar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      leading: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(color: Color(calendar.colorValue), shape: BoxShape.circle),
      ),
      title: Text(calendar.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: calendar.isDefault ? const Text('Default calendar') : null,
      onTap: () => _edit(context),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: calendar.isVisible,
            onChanged: (_) => controller.toggleCalendar(calendar.id),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) => value == 'edit' ? _edit(context) : _confirmDelete(context),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              if (!calendar.isDefault)
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final result = await showModalBottomSheet<CalendarModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CalendarEditorSheet(existing: calendar),
    );
    if (result != null) await controller.saveCalendar(result);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${calendar.name}?'),
        content: const Text('All events in this calendar will be deleted. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteCalendar(calendar.id);
  }
}
