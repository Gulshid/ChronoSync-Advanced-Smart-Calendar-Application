import 'package:flutter/material.dart';

import '../../data/models/occurrence.dart';
import '../../data/repositories/event_repository.dart';
import '../../state/calendar_controller.dart';
import 'event_detail_sheet.dart';
import 'event_editor_screen.dart';

/// Opens the full-screen editor. Pass [occurrence] to edit, or [defaultStart] to create.
Future<void> openEventEditor(
  BuildContext context,
  CalendarController controller, {
  Occurrence? occurrence,
  DateTime? defaultStart,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => EventEditorScreen(
        controller: controller,
        occurrence: occurrence,
        defaultStart: defaultStart,
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
                child: Text('$verb repeating event', style: theme.textTheme.titleMedium),
              ),
              ListTile(
                leading: const Icon(Icons.event_outlined),
                title: const Text('This event'),
                subtitle: const Text('Only this occurrence'),
                onTap: () => Navigator.pop(sheetContext, RecurrenceScope.thisEvent),
              ),
              ListTile(
                leading: const Icon(Icons.update),
                title: const Text('This and following events'),
                subtitle: const Text('This occurrence and all later ones'),
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
    final picked = await askRecurrenceScope(context, verb: 'Delete');
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
        content: const Text('Event deleted'),
        action: SnackBarAction(label: 'Undo', onPressed: () => controller.runUndo(undo)),
      ),
    );
}
