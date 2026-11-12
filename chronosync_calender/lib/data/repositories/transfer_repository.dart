import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/calendar_model.dart';
import '../models/event_model.dart';

/// Database access for import, export, backup and Google sync.
class TransferRepository {
  TransferRepository(this._db);

  final AppDatabase _db;

  Database get _raw => _db.raw;

  Future<List<CalendarModel>> calendars() async {
    final rows = await _raw.query('calendars', orderBy: 'sort_order ASC');
    return rows.map(CalendarModel.fromMap).toList();
  }

  Future<List<EventModel>> allEvents() async {
    final rows = await _raw.query('events');
    return rows.map(EventModel.fromMap).toList();
  }

  /// Rows that are synced as a whole: single events and series masters (not overrides).
  Future<List<EventModel>> syncableEvents() async {
    final rows = await _raw.query('events', where: 'parent_id IS NULL');
    return rows.map(EventModel.fromMap).toList();
  }

  /// Series masters or single events matching a UID, or whose id matches [id].
  Future<List<EventModel>> findByUidOrId(String uid, String? id) async {
    final rows = await _raw.query(
      'events',
      where: 'parent_id IS NULL AND (uid = ? OR id = ?)',
      whereArgs: [uid, id ?? ''],
    );
    return rows.map(EventModel.fromMap).toList();
  }

  Future<List<EventModel>> findByTitleAndStart(String title, DateTime start) async {
    final rows = await _raw.query(
      'events',
      where: 'parent_id IS NULL AND title = ? AND start_ms = ?',
      whereArgs: [title, start.toUtc().millisecondsSinceEpoch],
    );
    return rows.map(EventModel.fromMap).toList();
  }

  Future<EventModel?> findOverride(String parentId, DateTime originalStart) async {
    final rows = await _raw.query(
      'events',
      where: 'parent_id = ? AND original_start_ms = ?',
      whereArgs: [parentId, originalStart.toUtc().millisecondsSinceEpoch],
      limit: 1,
    );
    return rows.isEmpty ? null : EventModel.fromMap(rows.first);
  }

  Future<void> saveCalendar(CalendarModel calendar) =>
      AppDatabase.upsert(_raw, 'calendars', calendar.toMap());

  Future<void> saveEvent(EventModel event) => AppDatabase.upsert(_raw, 'events', event.toMap());

  Future<void> deleteEvent(String id) => _raw.delete('events', where: 'id = ?', whereArgs: [id]);

  Future<void> markSynced(String id, {required String googleId, required DateTime syncedAt}) {
    final ms = syncedAt.toUtc().millisecondsSinceEpoch;
    return _raw.update(
      'events',
      {'google_id': googleId, 'google_synced_ms': ms, 'updated_ms': ms},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Set<String>> syncableGoogleIds() async {
    final rows = await _raw.query(
      'events',
      columns: ['google_id'],
      where: 'parent_id IS NULL AND google_id IS NOT NULL',
    );
    return {for (final r in rows) r['google_id'] as String};
  }

  Future<List<Map<String, Object?>>> rawCalendars() => _raw.query('calendars');

  Future<List<Map<String, Object?>>> rawEvents() => _raw.query('events');

  /// Replaces every calendar and event. Used by backup restore.
  Future<void> replaceAll({
    required List<Map<String, Object?>> calendars,
    required List<Map<String, Object?>> events,
  }) {
    return _raw.transaction<void>((txn) async {
      await txn.delete('events');
      await txn.delete('calendars');
      for (final c in calendars) {
        await AppDatabase.upsert(txn, 'calendars', c);
      }
      // Series masters first, so overrides can point at them.
      final ordered = [...events]
        ..sort((a, b) => (a['parent_id'] == null ? 0 : 1).compareTo(b['parent_id'] == null ? 0 : 1));
      for (final e in ordered) {
        await AppDatabase.upsert(txn, 'events', e);
      }
    });
  }
}
