import 'event_model.dart';

/// One concrete appearance of an event on the calendar.
class Occurrence {
  const Occurrence({
    required this.event,
    required this.start,
    required this.end,
    required this.originalStart,
    required this.isGenerated,
    this.series,
  });

  /// The row this occurrence comes from (single event, override, or series master).
  final EventModel event;
  final DateTime start;
  final DateTime end;

  /// The series slot this occurrence fills. Equals [start] unless the occurrence was moved.
  final DateTime originalStart;

  /// True when a recurrence rule produced this occurrence.
  final bool isGenerated;

  /// The series master this occurrence belongs to, or null for single events.
  final EventModel? series;

  bool get isRecurring => isGenerated || event.parentId != null;
  bool get isAllDay => event.allDay;

  /// Stable key for widget identity and lookups.
  String get key => '${event.id}@${originalStart.millisecondsSinceEpoch}';

  bool overlaps(DateTime from, DateTime to) => start.isBefore(to) && end.isAfter(from);

  Occurrence clippedTo(DateTime from, DateTime to) => Occurrence(
        event: event,
        start: start.isBefore(from) ? from : start,
        end: end.isAfter(to) ? to : end,
        originalStart: originalStart,
        isGenerated: isGenerated,
        series: series,
      );
}
