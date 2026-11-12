import 'package:flutter/material.dart';

import 'package:chronosync_calender/core/utils/calendar_palette.dart';
import 'package:chronosync_calender/core/theme/app_theme.dart';
import 'package:chronosync_calender/core/utils/id_generator.dart';
import 'package:chronosync_calender/data/models/calendar_model.dart';

/// Bottom sheet to create or edit a calendar. Pops with the saved [CalendarModel].
class CalendarEditorSheet extends StatefulWidget {
  const CalendarEditorSheet({super.key, this.existing, this.nextSortOrder = 0});

  final CalendarModel? existing;
  final int nextSortOrder;

  @override
  State<CalendarEditorSheet> createState() => _CalendarEditorSheetState();
}

class _CalendarEditorSheetState extends State<CalendarEditorSheet> {
  late final TextEditingController _name;
  late int _color;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _color = widget.existing?.colorValue ?? calendarPalette[widget.nextSortOrder % calendarPalette.length];
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final existing = widget.existing;
    Navigator.pop(
      context,
      CalendarModel(
        id: existing?.id ?? newId(),
        name: name,
        colorValue: _color,
        isVisible: existing?.isVisible ?? true,
        isDefault: existing?.isDefault ?? false,
        sortOrder: existing?.sortOrder ?? widget.nextSortOrder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = widget.existing == null;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, MediaQuery.viewInsetsOf(context).bottom + AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isNew ? 'New calendar' : 'Edit calendar',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _name,
            autofocus: isNew,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Calendar name',
              prefixIcon: Icon(Icons.edit_calendar_outlined),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpace.xl),
          Text('Colour', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.md,
            runSpacing: AppSpace.md,
            children: [
              for (final value in calendarPalette)
                GestureDetector(
                  onTap: () => setState(() => _color = value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(value),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == value ? theme.colorScheme.onSurface : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: _color == value ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          FilledButton(
            onPressed: _submit,
            child: Text(isNew ? 'Create calendar' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
