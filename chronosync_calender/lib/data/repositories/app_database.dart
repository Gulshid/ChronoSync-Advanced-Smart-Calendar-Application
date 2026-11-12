import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:chronosync_calender/core/utils/calendar_palette.dart';

class AppDatabase {
  AppDatabase._(this.raw);

  /// The underlying sqflite handle. Only repositories should use it.
  final Database raw;

  static const _fileName = 'chronosync.db';

  /// v1: Phases 0 to 3. v2: reminders (Phase 4). v3: uid and Google sync fields (Phases 7 and 8).
  static const _version = 3;

  static const _schema = [
    '''
    CREATE TABLE calendars (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      color INTEGER NOT NULL,
      is_visible INTEGER NOT NULL DEFAULT 1,
      is_default INTEGER NOT NULL DEFAULT 0,
      sort_order INTEGER NOT NULL DEFAULT 0
    )''',
    '''
    CREATE TABLE events (
      id TEXT PRIMARY KEY,
      calendar_id TEXT NOT NULL REFERENCES calendars(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      location TEXT NOT NULL DEFAULT '',
      notes TEXT NOT NULL DEFAULT '',
      color INTEGER,
      all_day INTEGER NOT NULL DEFAULT 0,
      start_ms INTEGER NOT NULL,
      end_ms INTEGER NOT NULL,
      rrule TEXT,
      parent_id TEXT REFERENCES events(id) ON DELETE CASCADE,
      original_start_ms INTEGER,
      is_cancelled INTEGER NOT NULL DEFAULT 0,
      updated_ms INTEGER NOT NULL,
      reminders TEXT NOT NULL DEFAULT '',
      uid TEXT,
      google_id TEXT,
      google_synced_ms INTEGER
    )''',
    'CREATE INDEX idx_events_range ON events(start_ms, end_ms)',
    'CREATE INDEX idx_events_parent ON events(parent_id, original_start_ms)',
    'CREATE INDEX idx_events_google ON events(google_id)',
  ];

  static Future<AppDatabase> open({String? path}) async {
    final location = path ?? p.join(await getDatabasesPath(), _fileName);
    final db = await openDatabase(
      location,
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return AppDatabase._(db);
  }

  /// Updates the row with this id, or inserts it if none exists.
  ///
  /// Deliberately avoids REPLACE: that deletes the old row first, which would
  /// cascade-delete child rows (overrides) while foreign keys are on.
  static Future<void> upsert(DatabaseExecutor exec, String table, Map<String, Object?> row) async {
    final updated = await exec.update(table, row, where: 'id = ?', whereArgs: [row['id']]);
    if (updated == 0) await exec.insert(table, row);
  }

  static Future<void> _onCreate(Database db, int version) async {
    for (final sql in _schema) {
      await db.execute(sql);
    }
    final seeds = <Map<String, Object?>>[
      {'id': 'cal_personal', 'name': 'Personal', 'color': calendarPalette[0], 'is_visible': 1, 'is_default': 1, 'sort_order': 0},
      {'id': 'cal_work', 'name': 'Work', 'color': calendarPalette[1], 'is_visible': 1, 'is_default': 0, 'sort_order': 1},
      {'id': 'cal_holidays', 'name': 'Holidays', 'color': calendarPalette[2], 'is_visible': 1, 'is_default': 0, 'sort_order': 2},
    ];
    for (final row in seeds) {
      await db.insert('calendars', row);
    }
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE events ADD COLUMN reminders TEXT NOT NULL DEFAULT ''");
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE events ADD COLUMN uid TEXT');
      await db.execute('ALTER TABLE events ADD COLUMN google_id TEXT');
      await db.execute('ALTER TABLE events ADD COLUMN google_synced_ms INTEGER');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_events_google ON events(google_id)');
    }
  }
}
