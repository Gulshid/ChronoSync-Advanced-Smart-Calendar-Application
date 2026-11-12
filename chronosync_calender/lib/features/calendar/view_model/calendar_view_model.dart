import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:chronosync_calender/core/utils/date_helpers.dart';
import 'package:chronosync_calender/data/models/calendar_model.dart';
import 'package:chronosync_calender/data/models/event_model.dart';
import 'package:chronosync_calender/data/models/occurrence.dart';
import 'package:chronosync_calender/data/repositories/calendar_repository.dart';
import 'package:chronosync_calender/data/repositories/event_repository.dart';
import 'package:chronosync_calender/data/services/app_settings.dart';

enum CalendarViewMode { day, week, month, agenda }

/// How far an edit or delete reaches in a recurring series.
enum RecurrenceScope { thisEvent, thisAndFollowing }

/// Single source of truth for the calendar screens. Loads occurrences for the visible range.
class CalendarViewModel extends ChangeNotifier {
  CalendarViewModel({required EventRepository events, required CalendarRepository calendars})
      : _events = events,
        _calendars = calendars;

  final EventRepository _events;
  final CalendarRepository _calendars;

  /// Called after every data change, so reminders can be rescheduled.
  Future<void> Function(Set<String> calendarIds)? onDataChanged;

  DateTime _focus = startOfDay(DateTime.now());
  CalendarViewMode _view = CalendarViewMode.week;
  List<CalendarModel> _calendarList = const [];
  List<Occurrence> _occurrences = const [];

  /// Monday = 1 or Sunday = 7, from settings.
  int get firstWeekday => AppSettings.instance.weekStart;

  DateTime get focusDate => _focus;
  CalendarViewMode get view => _view;
  List<CalendarModel> get calendars => _calendarList;

  Set<String> get visibleCalendarIds => {for (final c in _calendarList) if (c.isVisible) c.id};

  String get defaultCalendarId {
    for (final c in _calendarList) {
      if (c.isDefault) return c.id;
    }
    return _calendarList.isEmpty ? 'cal_personal' : _calendarList.first.id;
  }

  /// The window of dates the current view needs.
  (DateTime, DateTime) get visibleRange => switch (_view) {
        CalendarViewMode.day => (_focus, addDays(_focus, 1)),
        CalendarViewMode.week => _weekRange(),
        CalendarViewMode.month => _monthRange(),
        CalendarViewMode.agenda => (_focus, addDays(_focus, 30)),
      };

  (DateTime, DateTime) _weekRange() {
    final start = startOfWeek(_focus, firstWeekday);
    return (start, addDays(start, 7));
  }

  (DateTime, DateTime) _monthRange() {
    final start = startOfWeek(DateTime(_focus.year, _focus.month, 1), firstWeekday);
    return (start, addDays(start, 42));
  }

  CalendarModel? calendarById(String id) {
    for (final c in _calendarList) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> init() async {
    _calendarList = await _calendars.all();
    await _changed();
  }

  Future<void> reload() async {
    final (from, to) = visibleRange;
    _occurrences = await _events.occurrencesBetween(from: from, to: to, calendarIds: visibleCalendarIds);
    notifyListeners();
  }

  /// Reloads the view and tells listeners (reminders) that data changed.
  Future<void> _changed() async {
    await reload();
    await onDataChanged?.call(visibleCalendarIds);
  }

  List<Occurrence> occurrencesBetween(DateTime from, DateTime to) =>
      [for (final o in _occurrences) if (o.overlaps(from, to)) o];

  List<Occurrence> occurrencesOn(DateTime day) {
    final start = startOfDay(day);
    return occurrencesBetween(start, addDays(start, 1));
  }

  /// Finds events whose title, location or notes contain [query]. Covers one year either side of today.
  Future<List<Occurrence>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final now = DateTime.now();
    final all = await _events.occurrencesBetween(
      from: addDays(now, -365),
      to: addDays(now, 365),
      calendarIds: visibleCalendarIds,
    );
    return [
      for (final o in all)
        if ([o.event.title, o.event.location, o.event.notes].any((s) => s.toLowerCase().contains(q))) o,
    ];
  }

  // Navigation -----------------------------------------------------------

  void setView(CalendarViewMode mode) {
    _view = mode;
    notifyListeners();
    reload();
  }

  void openDay(DateTime day) {
    _focus = startOfDay(day);
    _view = CalendarViewMode.day;
    notifyListeners();
    reload();
  }

  void goToday() {
    _focus = startOfDay(DateTime.now());
    notifyListeners();
    reload();
  }

  void shift(int direction) {
    _focus = switch (_view) {
      CalendarViewMode.day => addDays(_focus, direction),
      CalendarViewMode.week => addDays(_focus, 7 * direction),
      CalendarViewMode.agenda => addDays(_focus, 30 * direction),
      CalendarViewMode.month => _shiftMonth(direction),
    };
    notifyListeners();
    reload();
  }

  DateTime _shiftMonth(int months) {
    final target = DateTime(_focus.year, _focus.month + months, 1);
    final day = math.min(_focus.day, daysInMonth(target.year, target.month));
    return DateTime(target.year, target.month, day);
  }

  // Events ---------------------------------------------------------------

  Future<void> saveEvent({
    required EventModel draft,
    Occurrence? original,
    RecurrenceScope scope = RecurrenceScope.thisEvent,
  }) async {
    if (original == null || !original.isRecurring) {
      await _events.save(draft);
    } else if (scope == RecurrenceScope.thisEvent) {
      await _events.saveThisOccurrence(original, draft);
    } else {
      await _events.saveFollowing(original, draft);
    }
    await _changed();
  }

  Future<UndoAction> deleteOccurrence(Occurrence occ, RecurrenceScope scope) async {
    final undo = occ.isRecurring && scope == RecurrenceScope.thisAndFollowing
        ? await _events.deleteFollowing(occ)
        : await _events.deleteThisOccurrence(occ);
    await _changed();
    return undo;
  }

  Future<void> runUndo(UndoAction undo) async {
    await undo();
    await _changed();
  }

  // Calendars ------------------------------------------------------------

  Future<void> toggleCalendar(String id) async {
    final current = calendarById(id);
    if (current == null) return;
    await _calendars.setVisible(id, !current.isVisible);
    await _refreshCalendars();
  }

  Future<void> saveCalendar(CalendarModel calendar) async {
    await _calendars.save(calendar);
    await _refreshCalendars();
  }

  Future<void> deleteCalendar(String id) async {
    await _calendars.delete(id);
    await _refreshCalendars();
  }

  Future<void> _refreshCalendars() async {
    _calendarList = await _calendars.all();
    await _changed();
  }
}
