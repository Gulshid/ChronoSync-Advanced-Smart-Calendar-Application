import 'dart:convert';

import 'package:chronosync_calender/data/repositories/transfer_repository.dart';

/// Full backup of calendars and events as one JSON file.
class BackupService {
  BackupService(this._repo);

  final TransferRepository _repo;

  static const _format = 'ChronoSync backup';
  static const _schema = 3;

  Future<String> create() async {
    final payload = {
      'format': _format,
      'schema': _schema,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'calendars': await _repo.rawCalendars(),
      'events': await _repo.rawEvents(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Replaces all data with the backup. Throws [FormatException] if the file is not a usable backup.
  Future<int> restore(String text) async {
    final decoded = jsonDecode(text);
    if (decoded is! Map || decoded['format'] != _format) {
      throw const FormatException('not a ChronoSync backup');
    }
    final schema = decoded['schema'];
    if (schema is! int || schema > _schema) {
      throw const FormatException('backup from a newer app version');
    }
    final calendars = _rows(decoded['calendars']);
    final events = _rows(decoded['events']);
    await _repo.replaceAll(calendars: calendars, events: events);
    return events.length;
  }

  static List<Map<String, Object?>> _rows(Object? value) {
    if (value is! List) throw const FormatException('missing rows');
    return [for (final item in value) Map<String, Object?>.from(item as Map)];
  }
}
