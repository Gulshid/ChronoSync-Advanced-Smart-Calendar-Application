import 'package:flutter/material.dart';

import 'package:chronosync_calender/core/theme/app_theme.dart';
import 'package:chronosync_calender/data/models/calendar_model.dart';
import 'package:chronosync_calender/core/l10n/strings.dart';
import 'package:chronosync_calender/features/calendar/view_model/calendar_view_model.dart';
import 'package:chronosync_calender/features/calendars/view/calendar_editor_sheet.dart';

class CalendarsScreen extends StatelessWidget {
  const CalendarsScreen({super.key, required this.controller});

  final CalendarViewModel controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final calendars = controller.calendars;

        return Scaffold(
          appBar: AppBar(title: Text(Strings.t('calendars_title'))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, 96),
            children: [
              Text(
                Strings.t('calendars_hint'),
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpace.lg),
              Material(
                color: cs.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
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
            heroTag: 'calendars_fab',
            onPressed: () => _create(context),
            icon: const Icon(Icons.add),
            label: Text(Strings.t('new_calendar')),
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

  final CalendarViewModel controller;
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
      subtitle: calendar.isDefault ? Text(Strings.t('default_calendar')) : null,
      onTap: () => _edit(context),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: calendar.isVisible,
            onChanged: (_) => controller.toggleCalendar(calendar.id),
          ),
          PopupMenuButton<String>(
            tooltip: Strings.t('more'),
            onSelected: (value) => value == 'edit' ? _edit(context) : _confirmDelete(context),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(Strings.t('edit'))),
              if (!calendar.isDefault)
                PopupMenuItem(
                  value: 'delete',
                  child: Text(Strings.t('delete'), style: TextStyle(color: theme.colorScheme.error)),
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
        title: Text(Strings.t('delete_calendar_title', {'name': calendar.name})),
        content: Text(Strings.t('delete_calendar_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(Strings.t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(Strings.t('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteCalendar(calendar.id);
  }
}
