import 'package:sqflite/sqflite.dart';

import '../../core/utils/id_generator.dart';
import '../database/app_database.dart';
import '../models/event_model.dart';
import '../models/occurrence.dart';
import '../recurrence/occurrence_builder.dart';
import '../recurrence/recurrence_rule.dart';

/// Reverses a delete. Returned by every delete so the UI can offer Undo.
typedef UndoAction = Future<void> Function();

class EventRepository {
  EventRepository(this._db);

  final AppDatabase _db;

  Database get _raw => _db.raw;

  Future<List<Occurrence>> occurrencesBetween({
    required DateTime from,
    required DateTime to,
    required Set<String> calendarIds,
  }) async {
    // Loads every recurring master and every override, whatever their date. That way a
    // moved occurrence can still hide its original slot.
    final rows = await _raw.query(
      'events',
      where: 'rrule IS NOT NULL OR parent_id IS NOT NULL OR (start_ms < ? AND end_ms > ?)',
      whereArgs: [to.toUtc().millisecondsSinceEpoch, from.toUtc().millisecondsSinceEpoch],
    );
    final events = rows.map(EventModel.fromMap).where((e) => calendarIds.contains(e.calendarId));
    return OccurrenceBuilder.build(events: events, from: from, to: to);
  }

  Future<EventModel?> byId(String id) async {
    final rows = await _raw.query('events', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : EventModel.fromMap(rows.first);
  }

  /// Creates or updates a single row.
  Future<void> save(EventModel event) => AppDatabase.upsert(_raw, 'events', event.toMap());

  /// "This event": changes one occurrence of a series.
  Future<void> saveThisOccurrence(Occurrence occ, EventModel draft) {
    if (!occ.isGenerated) {
      // Already an override row. It stays an override and never becomes a series master.
      return save(draft.copyWith(rrule: null));
    }
    return save(draft.copyWith(
      id: newId(),
      rrule: null,
      parentId: occ.event.id,
      originalStart: occ.originalStart,
      isCancelled: false,
    ));
  }

  /// "This and following events": ends the old series before [occ] and starts a new one from [draft].
  Future<void> saveFollowing(Occurrence occ, EventModel draft) async {
    final master = await _masterOf(occ);
    if (master == null) return saveThisOccurrence(occ, draft);

    await _raw.transaction<void>((txn) async {
      await _cutSeries(txn, master, occ.originalStart);
      await AppDatabase.upsert(
        txn,
        'events',
        draft.copyWith(id: newId(), parentId: null, originalStart: null, isCancelled: false).toMap(),
      );
    });
  }

  /// Deletes one occurrence. Returns an action that restores it.
  Future<UndoAction> deleteThisOccurrence(Occurrence occ) async {
    final event = occ.event;

    if (occ.isGenerated) {
      final cancel = event.copyWith(
        id: newId(),
        rrule: null,
        parentId: event.id,
        originalStart: occ.originalStart,
        isCancelled: true,
      );
      await save(cancel);
      return _undo(created: [cancel.id]);
    }

    if (event.parentId != null) {
      // A moved occurrence is cancelled, not removed, so its original slot stays hidden.
      await save(event.copyWith(isCancelled: true));
      return _undo(snapshot: [event]);
    }

    await _raw.delete('events', where: 'id = ?', whereArgs: [event.id]);
    return _undo(snapshot: [event]);
  }

  /// Deletes this occurrence and every occurrence after it in the series.
  Future<UndoAction> deleteFollowing(Occurrence occ) async {
    final master = await _masterOf(occ);
    if (master == null) return deleteThisOccurrence(occ);

    final snapshot = await _raw.transaction<List<EventModel>>(
      (txn) => _cutSeries(txn, master, occ.originalStart),
    );
    return _undo(snapshot: snapshot);
  }

  /// The series master for [occ], or null when it is a single event.
  Future<EventModel?> _masterOf(Occurrence occ) async {
    final id = occ.event.parentId ?? occ.event.id;
    final master = await byId(id);
    return master?.rrule == null ? null : master;
  }

  /// Ends [master] just before [split]. Returns the rows it changed, so they can be restored.
  Future<List<EventModel>> _cutSeries(Transaction txn, EventModel master, DateTime split) async {
    final rule = RecurrenceRule.parse(master.rrule!);
    final before = OccurrenceBuilder.starts(
      dtStart: master.start,
      rule: rule,
      from: master.start,
      to: split,
    ).length;

    final splitMs = split.toUtc().millisecondsSinceEpoch;
    final removed = await txn.query(
      'events',
      where: 'parent_id = ? AND original_start_ms >= ?',
      whereArgs: [master.id, splitMs],
    );
    await txn.delete(
      'events',
      where: 'parent_id = ? AND original_start_ms >= ?',
      whereArgs: [master.id, splitMs],
    );

    if (before == 0) {
      await txn.delete('events', where: 'id = ?', whereArgs: [master.id]);
    } else {
      final capped = rule.count != null
          ? rule.copyWith(count: before, clearUntil: true)
          : rule.copyWith(until: split.subtract(const Duration(seconds: 1)));
      await txn.update(
        'events',
        {'rrule': capped.toRRule(), 'updated_ms': DateTime.now().toUtc().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [master.id],
      );
    }

    return [master, ...removed.map(EventModel.fromMap)];
  }

  UndoAction _undo({List<EventModel> snapshot = const [], List<String> created = const []}) {
    return () => _raw.transaction<void>((txn) async {
          for (final id in created) {
            await txn.delete('events', where: 'id = ?', whereArgs: [id]);
          }
          for (final row in snapshot) {
            await AppDatabase.upsert(txn, 'events', row.toMap());
          }
        });
  }
}
