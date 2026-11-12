import 'package:chronosync_calender/data/repositories/app_database.dart';
import 'package:chronosync_calender/data/models/calendar_model.dart';

class CalendarRepository {
  CalendarRepository(this._db);

  final AppDatabase _db;

  Future<List<CalendarModel>> all() async {
    final rows = await _db.raw.query('calendars', orderBy: 'sort_order ASC, name COLLATE NOCASE ASC');
    return rows.map(CalendarModel.fromMap).toList();
  }

  Future<void> save(CalendarModel calendar) => AppDatabase.upsert(_db.raw, 'calendars', calendar.toMap());

  Future<void> setVisible(String id, bool visible) => _db.raw.update(
        'calendars',
        {'is_visible': visible ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );

  /// Deletes a calendar and, through the foreign key, its events. The default calendar is protected.
  Future<void> delete(String id) async {
    final rows = await _db.raw.query('calendars', columns: ['is_default'], where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    if ((rows.first['is_default'] as int) == 1) {
      throw StateError('The default calendar cannot be deleted.');
    }
    await _db.raw.delete('calendars', where: 'id = ?', whereArgs: [id]);
  }
}
