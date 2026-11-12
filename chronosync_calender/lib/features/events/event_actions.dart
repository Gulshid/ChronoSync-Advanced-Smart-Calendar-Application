import 'package:flutter/material.dart';

import '../../data/models/occurrence.dart';
import '../../data/repositories/event_repository.dart';
import '../../l10n/strings.dart';
import '../../state/calendar_controller.dart';
import 'event_detail_sheet.dart';
import 'event_editor_screen.dart';

/// Opens the full-screen editor.
/// Pass [occurrence] to edit, or [defaultStart]/[defaultEnd] to create. [initialTitle] prefills from quick add.
Future<void> openEventEditor(
  BuildContext context,
  CalendarController controller, {
  Occurrence? occurrence,
  DateTime? defaultStart,
  DateTime? defaultEnd,
  String? initialTitle,
  bool initialAllDay = false,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => EventEditorScreen(
        controller: controller,
        occurrence: occurrence,
        defaultStart: defaultStart,
        defaultEnd: defaultEnd,
        initialTitle: initialTitle,
        initialAllDay: initialAllDay,
      ),
    ),
  );
}

Future<void> openEventDetail(BuildContext context, CalendarController controller, Occurrence occurrence) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => EventDetailSheet(
      controller: controller,
      occurrence: occurrence,
      hostContext: context,
    ),
  );
}

/// Asks whether a change applies to one occurrence or to the rest of the series.
Future<RecurrenceScope?> askRecurrenceScope(BuildContext context, {required String verb}) {
  return showModalBottomSheet<RecurrenceScope>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Text(Strings.t('scope_title', {'verb': verb}), style: theme.textTheme.titleMedium),
              ),
              ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text(Strings.t('scope_this')),
                subtitle: Text(Strings.t('scope_this_sub')),
                onTap: () => Navigator.pop(sheetContext, RecurrenceScope.thisEvent),
              ),
              ListTile(
                leading: const Icon(Icons.update),
                title: Text(Strings.t('scope_following')),
                subtitle: Text(Strings.t('scope_following_sub')),
                onTap: () => Navigator.pop(sheetContext, RecurrenceScope.thisAndFollowing),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Asks for a scope when needed, then deletes. Returns the undo action, or null if cancelled.
Future<UndoAction?> promptAndDelete(BuildContext context, CalendarController controller, Occurrence occ) async {
  var scope = RecurrenceScope.thisEvent;
  if (occ.isRecurring) {
    final picked = await askRecurrenceScope(context, verb: Strings.t('verb_delete'));
    if (picked == null) return null;
    scope = picked;
  }
  return controller.deleteOccurrence(occ, scope);
}

void showUndoSnack(ScaffoldMessengerState messenger, CalendarController controller, UndoAction undo) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(Strings.t('event_deleted')),
        action: SnackBarAction(label: Strings.t('undo'), onPressed: () => controller.runUndo(undo)),
      ),
    );
}
