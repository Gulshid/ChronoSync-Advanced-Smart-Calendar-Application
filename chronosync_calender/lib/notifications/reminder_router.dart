import '../app/app_navigator.dart';
import '../data/models/occurrence.dart';
import '../data/repositories/event_repository.dart';
import '../features/events/event_actions.dart';
import '../state/calendar_controller.dart';

/// Opens the event a tapped reminder refers to. Payload: "<eventId>|<startMs>".
Future<void> openReminder(String payload, EventRepository events, CalendarController controller) async {
  final parts = payload.split('|');
  if (parts.length != 2) return;
  final startMs = int.tryParse(parts[1]);
  final event = await events.byId(parts[0]);
  final context = appNavigatorKey.currentContext;
  if (event == null || startMs == null || context == null) return;

  final start = DateTime.fromMillisecondsSinceEpoch(startMs).toLocal();
  final recurring = event.rrule != null;
  final occurrence = Occurrence(
    event: event,
    start: start,
    end: start.add(event.end.difference(event.start)),
    originalStart: start,
    isGenerated: recurring,
    series: recurring ? event : null,
  );
  await openEventDetail(context, controller, occurrence);
}
