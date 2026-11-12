import '../../core/utils/id_generator.dart';

/// Sentinel that lets copyWith tell "not provided" apart from "set to null".
const Object _keep = Object();

/// One row in the events table. Times are local DateTimes and are stored as UTC.
class EventModel {
  const EventModel({
    required this.id,
    required this.calendarId,
    required this.title,
    required this.start,
    required this.end,
    required this.updatedAt,
    this.location = '',
    this.notes = '',
    this.colorValue,
    this.allDay = false,
    this.rrule,
    this.parentId,
    this.originalStart,
    this.isCancelled = false,
    this.reminderMinutes = const [],
  });

  factory EventModel.draft({
    required String calendarId,
    required DateTime start,
    required DateTime end,
    String title = '',
  }) =>
      EventModel(
        id: newId(),
        calendarId: calendarId,
        title: title,
        start: start,
        end: end,
        updatedAt: DateTime.now(),
      );

  final String id;
  final String calendarId;
  final String title;
  final String location;
  final String notes;
  final int? colorValue;
  final bool allDay;
  final DateTime start;
  final DateTime end;
  final String? rrule;
  final String? parentId;
  final DateTime? originalStart;
  final bool isCancelled;
  final DateTime updatedAt;

  /// Minutes before the start to remind (0 = at the start). Empty = no reminders.
  final List<int> reminderMinutes;

  EventModel copyWith({
    String? id,
    String? calendarId,
    String? title,
    String? location,
    String? notes,
    Object? colorValue = _keep,
    bool? allDay,
    DateTime? start,
    DateTime? end,
    Object? rrule = _keep,
    Object? parentId = _keep,
    Object? originalStart = _keep,
    bool? isCancelled,
    DateTime? updatedAt,
    List<int>? reminderMinutes,
  }) {
    return EventModel(
      id: id ?? this.id,
      calendarId: calendarId ?? this.calendarId,
      title: title ?? this.title,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      colorValue: _pick<int>(colorValue, this.colorValue),
      allDay: allDay ?? this.allDay,
      start: start ?? this.start,
      end: end ?? this.end,
      rrule: _pick<String>(rrule, this.rrule),
      parentId: _pick<String>(parentId, this.parentId),
      originalStart: _pick<DateTime>(originalStart, this.originalStart),
      isCancelled: isCancelled ?? this.isCancelled,
      updatedAt: updatedAt ?? DateTime.now(),
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    );
  }

  static T? _pick<T>(Object? value, T? current) => identical(value, _keep) ? current : value as T?;

  Map<String, Object?> toMap() => {
        'id': id,
        'calendar_id': calendarId,
        'title': title,
        'location': location,
        'notes': notes,
        'color': colorValue,
        'all_day': allDay ? 1 : 0,
        'start_ms': start.toUtc().millisecondsSinceEpoch,
        'end_ms': end.toUtc().millisecondsSinceEpoch,
        'rrule': rrule,
        'parent_id': parentId,
        'original_start_ms': originalStart?.toUtc().millisecondsSinceEpoch,
        'is_cancelled': isCancelled ? 1 : 0,
        'updated_ms': updatedAt.toUtc().millisecondsSinceEpoch,
        'reminders': reminderMinutes.join(','),
      };

  factory EventModel.fromMap(Map<String, Object?> m) {
    DateTime fromMs(Object? ms) => DateTime.fromMillisecondsSinceEpoch(ms as int).toLocal();
    final originalMs = m['original_start_ms'] as int?;
    final reminderText = (m['reminders'] as String?) ?? '';
    return EventModel(
      id: m['id'] as String,
      calendarId: m['calendar_id'] as String,
      title: m['title'] as String,
      location: m['location'] as String,
      notes: m['notes'] as String,
      colorValue: m['color'] as int?,
      allDay: (m['all_day'] as int) == 1,
      start: fromMs(m['start_ms']),
      end: fromMs(m['end_ms']),
      rrule: m['rrule'] as String?,
      parentId: m['parent_id'] as String?,
      originalStart: originalMs == null ? null : fromMs(originalMs),
      isCancelled: (m['is_cancelled'] as int) == 1,
      updatedAt: fromMs(m['updated_ms']),
      reminderMinutes: [
        for (final part in reminderText.split(','))
          if (int.tryParse(part) != null) int.parse(part),
      ],
    );
  }
}
