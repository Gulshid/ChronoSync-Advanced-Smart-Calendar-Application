import 'package:flutter/material.dart';

import 'package:chronosync_calender/core/l10n/strings.dart';
import 'package:chronosync_calender/core/theme/app_theme.dart';
import 'package:chronosync_calender/core/utils/calendar_palette.dart';
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
  String? _error;

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
    if (name.isEmpty) {
      setState(() => _error = Strings.t('name_required'));
      return;
    }
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
    final cs = theme.colorScheme;
    final isNew = widget.existing == null;
    final previewName = _name.text.trim().isEmpty ? Strings.t('calendar_name') : _name.text.trim();

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, MediaQuery.viewInsetsOf(context).bottom + AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            Strings.t(isNew ? 'new_calendar' : 'edit_calendar'),
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _name,
            autofocus: isNew,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: Strings.t('calendar_name'),
              prefixIcon: const Icon(Icons.edit_calendar_outlined),
              errorText: _error,
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(Strings.t('colour'), style: theme.textTheme.labelLarge),
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
                        color: _color == value ? cs.onSurface : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: _color == value ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          // Live preview so the user sees how the calendar will look in the list and on events.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.md),
            decoration: BoxDecoration(
              color: Color(_color).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border(left: BorderSide(color: Color(_color), width: 4)),
            ),
            child: Row(
              children: [
                Text(Strings.t('preview'), style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Text(
                    previewName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          FilledButton(
            onPressed: _submit,
            child: Text(Strings.t(isNew ? 'create_calendar' : 'save_changes')),
          ),
        ],
      ),
    );
  }
}
