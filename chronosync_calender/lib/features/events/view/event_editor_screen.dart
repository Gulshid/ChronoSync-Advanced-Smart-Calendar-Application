import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:chronosync_calender/core/utils/calendar_palette.dart';
import 'package:chronosync_calender/core/utils/app_format.dart';
import 'package:chronosync_calender/core/theme/app_theme.dart';
import 'package:chronosync_calender/core/utils/date_helpers.dart';
import 'package:chronosync_calender/core/utils/id_generator.dart';
import 'package:chronosync_calender/data/models/event_model.dart';
import 'package:chronosync_calender/data/models/occurrence.dart';
import 'package:chronosync_calender/data/services/occurrence_builder.dart';
import 'package:chronosync_calender/data/models/recurrence_rule.dart';
import 'package:chronosync_calender/core/l10n/strings.dart';
import 'package:chronosync_calender/data/services/app_settings.dart';
import 'package:chronosync_calender/features/calendar/view_model/calendar_view_model.dart';
import 'package:chronosync_calender/core/widgets/app_section.dart';
import 'package:chronosync_calender/features/events/view/event_actions.dart';

enum _Repeat { none, daily, weekly, monthly, yearly }

enum _Ends { never, onDate, afterCount }

/// Reminder lead times offered as chips (minutes before the start).
const _reminderPresets = [0, 5, 10, 15, 30, 60, 120, 1440, 2880, 10080];

class EventEditorScreen extends StatefulWidget {
  const EventEditorScreen({
    super.key,
    required this.controller,
    this.occurrence,
    this.defaultStart,
    this.defaultEnd,
    this.initialTitle,
    this.initialAllDay = false,
  });

  final CalendarViewModel controller;
  final Occurrence? occurrence;
  final DateTime? defaultStart;
  final DateTime? defaultEnd;
  final String? initialTitle;
  final bool initialAllDay;

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _intervalCtrl;
  late final TextEditingController _countCtrl;

  late bool _allDay;
  late DateTime _start;

  /// For all-day events this is exclusive: midnight after the last day.
  late DateTime _end;
  late String _calendarId;
  int? _colorValue;
  late _Repeat _repeat;
  late Set<int> _weekdays;
  late _Ends _endsMode;
  late Set<int> _reminders;
  DateTime? _untilDate;
  bool _saving = false;

  bool get _isRecurringOccurrence => widget.occurrence?.isRecurring ?? false;

  DateTime get _displayEnd => _allDay ? addDays(_end, -1) : _end;

  int get _interval => clampInt(int.tryParse(_intervalCtrl.text) ?? 1, 1, 99);

  int get _count => clampInt(int.tryParse(_countCtrl.text) ?? 10, 1, 999);

  @override
  void initState() {
    super.initState();
    final occ = widget.occurrence;
    final event = occ?.event;
    final series = occ?.series;
    final anchor = occ?.start ?? widget.defaultStart ?? _nextHalfHour();

    _titleCtrl = TextEditingController(text: event?.title ?? widget.initialTitle ?? '');
    _locationCtrl = TextEditingController(text: event?.location ?? '');
    _notesCtrl = TextEditingController(text: event?.notes ?? '');

    _allDay = event?.allDay ?? widget.initialAllDay;
    _start = _allDay ? startOfDay(anchor) : anchor;
    _end = occ?.end ?? widget.defaultEnd ?? _start.add(const Duration(hours: 1));
    _calendarId = event?.calendarId ?? widget.controller.defaultCalendarId;
    _colorValue = event?.colorValue;

    final defaultReminder = AppSettings.instance.defaultReminder;
    final initialReminders = event != null
        ? event.reminderMinutes
        : (defaultReminder >= 0 ? [defaultReminder] : const <int>[]);
    _reminders = {...initialReminders};

    final rule = series?.rrule == null ? null : RecurrenceRule.parse(series!.rrule!);
    _repeat = switch (rule?.frequency) {
      RecurFrequency.daily => _Repeat.daily,
      RecurFrequency.weekly => _Repeat.weekly,
      RecurFrequency.monthly => _Repeat.monthly,
      RecurFrequency.yearly => _Repeat.yearly,
      null => _Repeat.none,
    };
    _intervalCtrl = TextEditingController(text: '${rule?.interval ?? 1}');
    _weekdays = rule == null || rule.weekdays.isEmpty ? {anchor.weekday} : {...rule.weekdays};
    _endsMode = rule?.count != null
        ? _Ends.afterCount
        : rule?.until != null
            ? _Ends.onDate
            : _Ends.never;
    _countCtrl = TextEditingController(text: '${_remainingCount(rule, series, occ) ?? 10}');
    _untilDate = rule?.until == null ? null : startOfDay(rule!.until!.toLocal());
    _initialSnapshot = _snapshot();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    _intervalCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  /// Occurrences still to come. When editing from a later occurrence, COUNT shows what is left.
  int? _remainingCount(RecurrenceRule? rule, EventModel? series, Occurrence? occ) {
    if (rule?.count == null || series == null || occ == null) return rule?.count;
    final before = OccurrenceBuilder.starts(
      dtStart: series.start,
      rule: rule!,
      from: series.start,
      to: occ.originalStart,
    ).length;
    // ignore: unnecessary_non_null_assertion
    return rule!.count! - before;
  }

  DateTime _nextHalfHour() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour, now.minute < 30 ? 30 : 60);
  }

  RecurrenceRule? _buildRule() {
    if (_repeat == _Repeat.none) return null;
    final frequency = switch (_repeat) {
      _Repeat.daily => RecurFrequency.daily,
      _Repeat.weekly => RecurFrequency.weekly,
      _Repeat.monthly => RecurFrequency.monthly,
      _Repeat.yearly => RecurFrequency.yearly,
      _Repeat.none => RecurFrequency.daily,
    };
    final weekdays = _repeat == _Repeat.weekly
        ? (_weekdays.isEmpty ? [_start.weekday] : (_weekdays.toList()..sort()))
        : <int>[];
    final until = _untilDate;
    return RecurrenceRule(
      frequency: frequency,
      interval: _interval,
      weekdays: weekdays,
      count: _endsMode == _Ends.afterCount ? _count : null,
      until: _endsMode == _Ends.onDate && until != null
          ? DateTime(until.year, until.month, until.day, 23, 59, 59)
          : null,
    );
  }

  // Date and time edits ---------------------------------------------------

  void _toggleAllDay(bool value) {
    setState(() {
      _allDay = value;
      if (value) {
        _start = startOfDay(_start);
        _end = addDays(_start, 1);
      } else {
        _start = DateTime(_start.year, _start.month, _start.day, 9);
        _end = _start.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      final duration = _end.difference(_start);
      final span = calendarDaysBetween(_start, _end);
      _start = _allDay
          ? DateTime(picked.year, picked.month, picked.day)
          : DateTime(picked.year, picked.month, picked.day, _start.hour, _start.minute);
      _end = _allDay ? addDays(_start, span) : _start.add(duration);
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
    if (picked == null) return;
    setState(() {
      final duration = _end.difference(_start);
      _start = DateTime(_start.year, _start.month, _start.day, picked.hour, picked.minute);
      _end = _start.add(duration);
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _displayEnd,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _end = _allDay
          ? addDays(DateTime(picked.year, picked.month, picked.day), 1)
          : DateTime(picked.year, picked.month, picked.day, _end.hour, _end.minute);
    });
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_end));
    if (picked == null) return;
    setState(() => _end = DateTime(_end.year, _end.month, _end.day, picked.hour, picked.minute));
  }

  Future<void> _pickUntilDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _untilDate ?? _start,
      firstDate: _start,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _untilDate = picked);
  }

  // Save and delete ------------------------------------------------------

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final start = _allDay ? startOfDay(_start) : _start;
    final end = _allDay ? startOfDay(_end) : _end;
    if (!end.isAfter(start)) {
      _showMessage(Strings.t('end_after_start'));
      return;
    }

    final occ = widget.occurrence;
    var scope = RecurrenceScope.thisEvent;
    if (occ != null && occ.isRecurring) {
      final picked = await askRecurrenceScope(context, verb: Strings.t('verb_save'));
      if (picked == null) return;
      scope = picked;
    }

    final rule = _buildRule();
    final reminders = _reminders.toList()..sort();
    final base = occ?.event;
    final draft = base == null
        ? EventModel(
            id: newId(),
            calendarId: _calendarId,
            title: _titleCtrl.text.trim(),
            location: _locationCtrl.text.trim(),
            notes: _notesCtrl.text.trim(),
            colorValue: _colorValue,
            allDay: _allDay,
            start: start,
            end: end,
            rrule: rule?.toRRule(),
            reminderMinutes: reminders,
            updatedAt: DateTime.now(),
          )
        : base.copyWith(
            calendarId: _calendarId,
            title: _titleCtrl.text.trim(),
            location: _locationCtrl.text.trim(),
            notes: _notesCtrl.text.trim(),
            colorValue: _colorValue,
            allDay: _allDay,
            start: start,
            end: end,
            rrule: rule?.toRRule(),
            reminderMinutes: reminders,
          );

    setState(() => _saving = true);
    try {
      await widget.controller.saveEvent(draft: draft, original: occ, scope: scope);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(Strings.t('save_failed', {'error': '$error'}));
    }
  }

  Future<void> _delete() async {
    final occ = widget.occurrence;
    if (occ == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final undo = await promptAndDelete(context, widget.controller, occ);
    if (undo == null) return;
    if (mounted) Navigator.pop(context);
    showUndoSnack(messenger, widget.controller, undo);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Unsaved-change tracking ----------------------------------------------

  late final String _initialSnapshot;

  String _snapshot() => [
        _titleCtrl.text,
        _locationCtrl.text,
        _notesCtrl.text,
        _allDay,
        _start,
        _end,
        _calendarId,
        _colorValue,
        _repeat,
        ([..._weekdays]..sort()),
        _endsMode,
        ([..._reminders]..sort()),
        _untilDate,
        _intervalCtrl.text,
        _countCtrl.text,
      ].join('|');

  bool get _dirty => _snapshot() != _initialSnapshot;

  Future<bool> _confirmDiscard() async {
    final cs = Theme.of(context).colorScheme;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(Strings.t('discard_title')),
        content: Text(Strings.t('discard_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(Strings.t('keep_editing')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(Strings.t('discard')),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  // Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final calendars = widget.controller.calendars;
    final isEdit = widget.occurrence != null;
    final duration = _durationLabel();

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (discard && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: Strings.t('close'),
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(Strings.t(isEdit ? 'edit_event' : 'new_event')),
          actions: [
            if (isEdit)
              IconButton(
                tooltip: Strings.t('delete'),
                icon: Icon(Icons.delete_outline, color: cs.error),
                onPressed: _delete,
              ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpace.sm),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(Strings.t('save')),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xl),
            children: [
              TextFormField(
                controller: _titleCtrl,
                autofocus: !isEdit,
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: Strings.t('add_title'),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? Strings.t('title_required') : null,
              ),
              const SizedBox(height: AppSpace.md),
              AppSection(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(Icons.wb_sunny_outlined, color: cs.onSurfaceVariant),
                    title: Text(Strings.t('all_day')),
                    value: _allDay,
                    onChanged: _toggleAllDay,
                  ),
                  const Divider(height: AppSpace.xl),
                  _DateTimeRow(
                    label: Strings.t('starts'),
                    dateText: DateFormat('EEE, MMM d, y').format(_start),
                    onDate: _pickStartDate,
                    timeText: _allDay ? null : AppFormat.time(_start),
                    onTime: _allDay ? null : _pickStartTime,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _DateTimeRow(
                    label: Strings.t('ends'),
                    dateText: DateFormat('EEE, MMM d, y').format(_displayEnd),
                    onDate: _pickEndDate,
                    timeText: _allDay ? null : AppFormat.time(_end),
                    onTime: _allDay ? null : _pickEndTime,
                  ),
                  if (duration != null) ...[
                    const SizedBox(height: AppSpace.md),
                    Text(
                      duration,
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpace.md),
              AppSection(
                title: Strings.t('calendar'),
                icon: Icons.calendar_month_outlined,
                children: [
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: [
                      for (final c in calendars)
                        ChoiceChip(
                          avatar: CircleAvatar(backgroundColor: Color(c.colorValue), radius: 6),
                          label: Text(c.name),
                          selected: _calendarId == c.id,
                          onSelected: (_) => setState(() => _calendarId = c.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _SectionLabel(Strings.t('colour')),
                  Wrap(
                    spacing: AppSpace.md,
                    runSpacing: AppSpace.md,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChoiceChip(
                        label: Text(Strings.t('calendar_colour')),
                        selected: _colorValue == null,
                        onSelected: (_) => setState(() => _colorValue = null),
                      ),
                      for (final value in calendarPalette)
                        _ColorDot(
                          color: Color(value),
                          selected: _colorValue == value,
                          onTap: () => setState(() => _colorValue = value),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              AppSection(
                children: [
                  TextFormField(
                    controller: _locationCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: Strings.t('add_location'),
                      prefixIcon: const Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  TextFormField(
                    controller: _notesCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: Strings.t('add_notes'),
                      prefixIcon: const Icon(Icons.notes_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              AppSection(
                title: Strings.t('reminders'),
                icon: Icons.notifications_none,
                children: _reminderChildren(),
              ),
              const SizedBox(height: AppSpace.md),
              AppSection(
                title: Strings.t('repeat'),
                icon: Icons.repeat,
                children: _repeatChildren(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "1 hour" or "1 h 30 min" for timed events. Null for all-day events.
  String? _durationLabel() {
    if (_allDay) return null;
    final length = _end.difference(_start);
    if (length.isNegative || length.inMinutes == 0) return null;
    return Strings.durationText(length);
  }

  List<Widget> _reminderChildren() => [
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final m in _reminderPresets)
              FilterChip(
                avatar: Icon(
                  _reminders.contains(m) ? Icons.notifications_active_outlined : Icons.notifications_none,
                  size: 16,
                ),
                label: Text(Strings.leadLabel(m)),
                selected: _reminders.contains(m),
                onSelected: (on) {
                  setState(() {
                    if (on) {
                      _reminders.add(m);
                    } else {
                      _reminders.remove(m);
                    }
                  });
                },
              ),
          ],
        ),
      ];

  List<Widget> _repeatChildren(ThemeData theme) {
    final cs = theme.colorScheme;
    return [
      Wrap(
        spacing: AppSpace.sm,
        runSpacing: AppSpace.sm,
        children: [
          for (final r in _Repeat.values)
            ChoiceChip(
              label: Text(_repeatLabel(r)),
              selected: _repeat == r,
              onSelected: (_) => setState(() => _repeat = r),
            ),
        ],
      ),
      if (_repeat != _Repeat.none) ...[
        const SizedBox(height: AppSpace.lg),
        Row(
          children: [
            SizedBox(
              width: 72,
              child: TextField(
                controller: _intervalCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Text(_unitWord()),
          ],
        ),
        if (_repeat == _Repeat.weekly) ...[
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(DateFormat.E().format(DateTime(2024, 1, d))),
                  selected: _weekdays.contains(d),
                  onSelected: (on) {
                    setState(() {
                      if (on) {
                        _weekdays.add(d);
                      } else {
                        _weekdays.remove(d);
                      }
                    });
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpace.lg),
        _SectionLabel(Strings.t('ends')),
        SegmentedButton<_Ends>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: _Ends.never, label: Text(Strings.t('ends_never'))),
            ButtonSegment(value: _Ends.onDate, label: Text(Strings.t('ends_on'))),
            ButtonSegment(value: _Ends.afterCount, label: Text(Strings.t('ends_after'))),
          ],
          selected: {_endsMode},
          onSelectionChanged: (s) => setState(() => _endsMode = s.first),
        ),
        if (_endsMode == _Ends.onDate) ...[
          const SizedBox(height: AppSpace.md),
          ActionChip(
            avatar: const Icon(Icons.event_busy_outlined, size: 16),
            label: Text(_untilDate == null
                ? Strings.t('choose_end')
                : DateFormat('EEE, MMM d, y').format(_untilDate!)),
            onPressed: _pickUntilDate,
          ),
        ],
        if (_endsMode == _Ends.afterCount) ...[
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _countCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Text(Strings.t('occurrences')),
            ],
          ),
        ],
      ],
      const SizedBox(height: AppSpace.md),
      Text(
        _repeatSummary(),
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      if (_isRecurringOccurrence) ...[
        const SizedBox(height: AppSpace.xs),
        Text(
          Strings.t('repeat_hint'),
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    ];
  }

  String _repeatLabel(_Repeat r) => switch (r) {
        _Repeat.none => Strings.t('repeat_none'),
        _Repeat.daily => Strings.t('repeat_daily'),
        _Repeat.weekly => Strings.t('repeat_weekly'),
        _Repeat.monthly => Strings.t('repeat_monthly'),
        _Repeat.yearly => Strings.t('repeat_yearly'),
      };

  String _unitWord() {
    final plural = _interval != 1;
    return switch (_repeat) {
      _Repeat.daily => Strings.t(plural ? 'unit_days' : 'unit_day'),
      _Repeat.weekly => Strings.t(plural ? 'unit_weeks' : 'unit_week'),
      _Repeat.monthly => Strings.t(plural ? 'unit_months' : 'unit_month'),
      _Repeat.yearly => Strings.t(plural ? 'unit_years' : 'unit_year'),
      _Repeat.none => '',
    };
  }

  String _repeatSummary() {
    if (_repeat == _Repeat.none) return Strings.t('does_not_repeat');
    final every = _interval == 1
        ? Strings.t('summary_one', {'unit': _unitWord()})
        : Strings.t('summary_every', {'n': _interval, 'unit': _unitWord()});
    final weekdayNames = ([..._weekdays]..sort())
        .map((d) => DateFormat.E().format(DateTime(2024, 1, d)))
        .join(', ');
    final days = _repeat == _Repeat.weekly
        ? ' · ${Strings.t('on_days', {'days': weekdayNames})}'
        : '';
    final untilDate = _untilDate;
    final ends = switch (_endsMode) {
      _Ends.never => '',
      _Ends.onDate => untilDate == null
          ? ''
          : ' · ${Strings.t('until', {'date': DateFormat('MMM d, y').format(untilDate)})}',
      _Ends.afterCount => ' · ${Strings.t('times', {'n': _count})}',
    };
    return '$every$days$ends';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// Label above two tappable chips: the date, and the time for timed events.
class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.label,
    required this.dateText,
    required this.onDate,
    this.timeText,
    this.onTime,
  });

  final String label;
  final String dateText;
  final VoidCallback onDate;
  final String? timeText;
  final VoidCallback? onTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpace.xs),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            ActionChip(
              avatar: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(dateText),
              onPressed: onDate,
            ),
            if (timeText != null)
              ActionChip(
                avatar: const Icon(Icons.schedule, size: 16),
                label: Text(timeText!),
                onPressed: onTime,
              ),
          ],
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? cs.onSurface : Colors.transparent, width: 2.5),
        ),
        child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
      ),
    );
  }
}
