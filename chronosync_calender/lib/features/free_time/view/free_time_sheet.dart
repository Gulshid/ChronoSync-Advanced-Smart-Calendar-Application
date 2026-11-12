import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:chronosync_calender/core/l10n/strings.dart';
import 'package:chronosync_calender/core/theme/app_theme.dart';
import 'package:chronosync_calender/core/utils/app_format.dart';
import 'package:chronosync_calender/core/utils/date_helpers.dart';
import 'package:chronosync_calender/core/widgets/app_section.dart';
import 'package:chronosync_calender/core/widgets/empty_state.dart';
import 'package:chronosync_calender/data/services/free_time_finder.dart';
import 'package:chronosync_calender/features/calendar/view_model/calendar_view_model.dart';
import 'package:chronosync_calender/features/events/view/event_actions.dart';

Future<void> openFreeTime(BuildContext context, CalendarViewModel controller) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => FreeTimeSheet(controller: controller, hostContext: context),
  );
}

/// Finds gaps in a day's schedule. Tapping a gap opens the editor pre-filled with that time.
class FreeTimeSheet extends StatefulWidget {
  const FreeTimeSheet({super.key, required this.controller, required this.hostContext});

  final CalendarViewModel controller;
  final BuildContext hostContext;

  @override
  State<FreeTimeSheet> createState() => _FreeTimeSheetState();
}

class _FreeTimeSheetState extends State<FreeTimeSheet> {
  static const _lengths = [30, 60, 90, 120];
  static const _hours = [(9, 17), (8, 18), (7, 22)];

  late DateTime _day = startOfDay(widget.controller.focusDate);
  int _minutes = 60;
  int _hoursIndex = 0;

  void _shiftDay(int d) => setState(() => _day = addDays(_day, d));

  void _openSlot(FreeSlot slot) {
    Navigator.pop(context);
    openEventEditor(widget.hostContext, widget.controller, defaultStart: slot.start, defaultEnd: slot.end);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (startHour, endHour) = _hours[_hoursIndex];
    final slots = FreeTimeFinder.find(
      day: _day,
      occurrences: widget.controller.occurrencesOn(_day),
      workStartHour: startHour,
      workEndHour: endHour,
      minLength: Duration(minutes: _minutes),
    );

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(Strings.t('free_time'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpace.sm),
            // Day stepper
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: Strings.t('previous'),
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _shiftDay(-1),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat.yMMMEd().format(_day),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: Strings.t('next'),
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _shiftDay(1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            AppSection(
              children: [
                Text(Strings.t('free_length'), style: theme.textTheme.labelLarge),
                const SizedBox(height: AppSpace.sm),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    for (final m in _lengths)
                      ChoiceChip(
                        label: Text(Strings.durationText(Duration(minutes: m))),
                        selected: _minutes == m,
                        onSelected: (_) => setState(() => _minutes = m),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                Text(Strings.t('free_hours'), style: theme.textTheme.labelLarge),
                const SizedBox(height: AppSpace.sm),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    for (var i = 0; i < _hours.length; i++)
                      ChoiceChip(
                        label: Text('${AppFormat.hour(_hours[i].$1)} – ${AppFormat.hour(_hours[i].$2)}'),
                        selected: _hoursIndex == i,
                        onSelected: (_) => setState(() => _hoursIndex = i),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Expanded(
              child: slots.isEmpty
                  ? EmptyState(
                      icon: Icons.event_busy_outlined,
                      title: Strings.t('free_time'),
                      message: Strings.t('free_none'),
                    )
                  : ListView.separated(
                      itemCount: slots.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpace.sm),
                      itemBuilder: (context, i) {
                        final slot = slots[i];
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
                            leading: const IconBadge(icon: Icons.hourglass_empty),
                            title: Text(AppFormat.range(slot.start, slot.end), style: theme.textTheme.titleSmall),
                            subtitle: Text(Strings.durationText(slot.length)),
                            trailing: Icon(Icons.add_circle_outline, color: cs.primary),
                            onTap: () => _openSlot(slot),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
