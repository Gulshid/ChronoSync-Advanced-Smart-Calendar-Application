import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/calendar_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_helpers.dart';
import '../../core/utils/id_generator.dart';
import '../../data/models/event_model.dart';
import '../../data/models/occurrence.dart';
import '../../data/recurrence/occurrence_builder.dart';
import '../../data/recurrence/recurrence_rule.dart';
import '../../state/calendar_controller.dart';
import 'event_actions.dart';

enum _Repeat { none, daily, weekly, monthly, yearly }

enum _Ends { never, onDate, afterCount }

class EventEditorScreen extends StatefulWidget {
  const EventEditorScreen({
    super.key,
    required this.controller,
    this.occurrence,
    this.defaultStart,
  });

  final CalendarController controller;
  final Occurrence? occurrence;
  final DateTime? defaultStart;

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

    _titleCtrl = TextEditingController(text: event?.title ?? '');
    _locationCtrl = TextEditingController(text: event?.location ?? '');
    _notesCtrl = TextEditingController(text: event?.notes ?? '');

    _allDay = event?.allDay ?? false;
    _start = _allDay ? startOfDay(anchor) : anchor;
    _end = occ?.end ?? _start.add(const Duration(hours: 1));
    _calendarId = event?.calendarId ?? _defaultCalendarId();
    _colorValue = event?.colorValue;

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

  String _defaultCalendarId() {
    final calendars = widget.controller.calendars;
    for (final c in calendars) {
      if (c.isDefault) return c.id;
    }
    return calendars.isEmpty ? 'cal_personal' : calendars.first.id;
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
      _showMessage('The end must be after the start.');
      return;
    }

    final occ = widget.occurrence;
    var scope = RecurrenceScope.thisEvent;
    if (occ != null && occ.isRecurring) {
      final picked = await askRecurrenceScope(context, verb: 'Save');
      if (picked == null) return;
      scope = picked;
    }

    final rule = _buildRule();
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
          );

    setState(() => _saving = true);
    try {
      await widget.controller.saveEvent(draft: draft, original: occ, scope: scope);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Could not save the event. $error');
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

  // Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final calendars = widget.controller.calendars;
    final isEdit = widget.occurrence != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isEdit ? 'Edit event' : 'New event'),
        actions: [
          if (isEdit)
            IconButton(
              tooltip: 'Delete',
              icon: Icon(Icons.delete_outline, color: cs.error),
              onPressed: _delete,
            ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.sm),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
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
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(hintText: 'Add title'),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Please add a title' : null,
            ),
            const SizedBox(height: AppSpace.lg),
            _Section(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All day'),
                  value: _allDay,
                  onChanged: _toggleAllDay,
                ),
                const Divider(height: AppSpace.xl),
                _DateTimeRow(
                  label: 'Starts',
                  dateText: DateFormat('EEE, MMM d, y').format(_start),
                  onDate: _pickStartDate,
                  timeText: _allDay ? null : DateFormat.jm().format(_start),
                  onTime: _allDay ? null : _pickStartTime,
                ),
                const SizedBox(height: AppSpace.sm),
                _DateTimeRow(
                  label: 'Ends',
                  dateText: DateFormat('EEE, MMM d, y').format(_displayEnd),
                  onDate: _pickEndDate,
                  timeText: _allDay ? null : DateFormat.jm().format(_end),
                  onTime: _allDay ? null : _pickEndTime,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            _Section(
              children: [
                _SectionLabel('Calendar'),
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
                _SectionLabel('Colour'),
                Wrap(
                  spacing: AppSpace.md,
                  runSpacing: AppSpace.md,
                  children: [
                    ChoiceChip(
                      label: const Text('Calendar colour'),
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
            _Section(
              children: [
                TextFormField(
                  controller: _locationCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Add location', prefixIcon: Icon(Icons.place_outlined)),
                ),
                const SizedBox(height: AppSpace.md),
                TextFormField(
                  controller: _notesCtrl,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(hintText: 'Add notes', prefixIcon: Icon(Icons.notes_outlined)),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            _Section(children: _repeatChildren(theme)),
          ],
        ),
      ),
    );
  }

  List<Widget> _repeatChildren(ThemeData theme) {
    final cs = theme.colorScheme;
    return [
      _SectionLabel('Repeat'),
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
            const Text('Every'),
            const SizedBox(width: AppSpace.md),
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
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(DateFormat.E().format(DateTime(2024, 1, d))),
                  selected: _weekdays.contains(d),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _weekdays.add(d);
                    } else {
                      _weekdays.remove(d);
                    }
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpace.lg),
        _SectionLabel('Ends'),
        SegmentedButton<_Ends>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _Ends.never, label: Text('Never')),
            ButtonSegment(value: _Ends.onDate, label: Text('On date')),
            ButtonSegment(value: _Ends.afterCount, label: Text('After')),
          ],
          selected: {_endsMode},
          onSelectionChanged: (s) => setState(() => _endsMode = s.first),
        ),
        if (_endsMode == _Ends.onDate) ...[
          const SizedBox(height: AppSpace.md),
          ActionChip(
            avatar: const Icon(Icons.event_busy_outlined, size: 16),
            label: Text(_untilDate == null ? 'Choose end date' : DateFormat('EEE, MMM d, y').format(_untilDate!)),
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
              const Text('occurrences'),
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
          "Changes to repeat apply when you choose 'This and following events'.",
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    ];
  }

  String _repeatLabel(_Repeat r) => switch (r) {
        _Repeat.none => 'None',
        _Repeat.daily => 'Daily',
        _Repeat.weekly => 'Weekly',
        _Repeat.monthly => 'Monthly',
        _Repeat.yearly => 'Yearly',
      };

  String _unitWord() {
    final plural = _interval != 1;
    return switch (_repeat) {
      _Repeat.daily => plural ? 'days' : 'day',
      _Repeat.weekly => plural ? 'weeks' : 'week',
      _Repeat.monthly => plural ? 'months' : 'month',
      _Repeat.yearly => plural ? 'years' : 'year',
      _Repeat.none => '',
    };
  }

  String _repeatSummary() {
    if (_repeat == _Repeat.none) return 'Does not repeat';
    final every = _interval == 1 ? 'Every ${_unitWord()}' : 'Every $_interval ${_unitWord()}';
    final days = _repeat == _Repeat.weekly
        ? ' on ${([..._weekdays]..sort()).map((d) => DateFormat.E().format(DateTime(2024, 1, d))).join(', ')}'
        : '';
    final ends = switch (_endsMode) {
      _Ends.never => '',
      _Ends.onDate => _untilDate == null ? '' : ', until ${DateFormat('MMM d, y').format(_untilDate!)}',
      _Ends.afterCount => ', $_count times',
    };
    return '$every$days$ends';
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
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
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: theme.textTheme.labelLarge),
        ),
        Flexible(
          child: ActionChip(
            avatar: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(dateText),
            onPressed: onDate,
          ),
        ),
        if (timeText != null) ...[
          const SizedBox(width: AppSpace.sm),
          ActionChip(
            avatar: const Icon(Icons.schedule, size: 16),
            label: Text(timeText!),
            onPressed: onTime,
          ),
        ],
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
