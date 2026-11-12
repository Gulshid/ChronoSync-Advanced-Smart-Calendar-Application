import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format/app_format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/event_model.dart';
import '../../l10n/strings.dart';
import '../../state/app_settings.dart';
import '../../state/calendar_controller.dart';
import '../events/event_actions.dart';
import 'quick_add_parser.dart';

/// Opens the quick-add sheet: type a sentence, check the preview, then create.
Future<void> openQuickAdd(BuildContext context, CalendarController controller) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => QuickAddSheet(controller: controller, hostContext: context),
  );
}

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key, required this.controller, required this.hostContext});

  final CalendarController controller;
  final BuildContext hostContext;

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  final _text = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  QuickAddResult? get _parsed =>
      _text.text.trim().isEmpty ? null : QuickAddParser.parse(_text.text, now: DateTime.now());

  Future<void> _create() async {
    final parsed = _parsed;
    if (parsed == null) return;
    setState(() => _saving = true);
    final reminder = AppSettings.instance.defaultReminder;
    final draft = EventModel(
      id: newId(),
      calendarId: widget.controller.defaultCalendarId,
      title: parsed.title,
      start: parsed.start,
      end: parsed.end,
      allDay: parsed.allDay,
      reminderMinutes: reminder >= 0 ? [reminder] : const [],
      updatedAt: DateTime.now(),
    );
    await widget.controller.saveEvent(draft: draft);
    if (mounted) Navigator.pop(context);
  }

  void _moreOptions() {
    final parsed = _parsed;
    Navigator.pop(context);
    openEventEditor(
      widget.hostContext,
      widget.controller,
      defaultStart: parsed?.start,
      defaultEnd: parsed?.end,
      initialTitle: parsed?.title ?? _text.text.trim(),
      initialAllDay: parsed?.allDay ?? false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = _parsed;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.xl,
        0,
        AppSpace.xl,
        MediaQuery.viewInsetsOf(context).bottom + AppSpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            Strings.t('quick_add'),
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            Strings.t('quick_add_help'),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _text,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _create(),
            decoration: InputDecoration(
              hintText: Strings.t('quick_add_hint'),
              prefixIcon: const Icon(Icons.bolt_outlined),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          if (parsed != null) _Preview(parsed: parsed),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _moreOptions,
                  child: Text(Strings.t('edit_details')),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: FilledButton(
                  onPressed: parsed == null || _saving ? null : _create,
                  child: Text(Strings.t('create')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.parsed});

  final QuickAddResult parsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant);

    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parsed.title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: AppSpace.sm),
              Text(DateFormat.yMMMEd().format(parsed.start), style: muted),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: AppSpace.sm),
              Text(
                parsed.allDay
                    ? Strings.t('all_day')
                    : '${AppFormat.range(parsed.start, parsed.end)}  ·  ${Strings.durationText(parsed.end.difference(parsed.start))}',
                style: muted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
