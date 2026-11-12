import '../../core/constants/calendar_palette.dart';
import '../../core/utils/id_generator.dart';
import '../ics/ics_reader.dart';
import '../models/calendar_model.dart';
import '../models/event_model.dart';
import '../repositories/transfer_repository.dart';

class ImportReport {
  const ImportReport({required this.added, required this.skipped, required this.rulesSkipped});

  final int added;
  final int skipped;
  final int rulesSkipped;
}

/// Imports .ics text. Events already on the phone are skipped, matched by UID or by title and start time.
class IcsImportService {
  IcsImportService(this._repo);

  final TransferRepository _repo;

  static const _uidSuffix = '@chronosync';

  Future<ImportReport> importText(String text) async {
    final read = IcsReader.read(text);
    final calendars = await _repo.calendars();
    final byName = {for (final c in calendars) c.name.toLowerCase(): c};
    final defaultCalendar = calendars.firstWhere((c) => c.isDefault, orElse: () => calendars.first);

    var added = 0;
    var skipped = 0;
    final mastersByUid = <String, EventModel>{};

    Future<String> calendarIdFor(String? name) async {
      final clean = name?.trim() ?? '';
      if (clean.isEmpty) return defaultCalendar.id;
      final key = clean.toLowerCase();
      final existing = byName[key];
      if (existing != null) return existing.id;
      final created = CalendarModel(
        id: newId(),
        name: clean,
        colorValue: calendarPalette[byName.length % calendarPalette.length],
        sortOrder: byName.length,
      );
      await _repo.saveCalendar(created);
      byName[key] = created;
      return created.id;
    }

    // Pass 1: series masters and single events.
    for (final r in read.records.where((r) => r.recurrenceId == null)) {
      final existing = await _findExisting(r);
      EventModel master;
      if (existing != null) {
        master = existing;
        skipped++;
      } else {
        master = EventModel(
          id: newId(),
          calendarId: await calendarIdFor(r.calendarName),
          title: r.title,
          location: r.location,
          notes: r.notes,
          allDay: r.allDay,
          start: r.start,
          end: r.end,
          rrule: r.rrule,
          reminderMinutes: r.reminders,
          uid: r.uid,
          updatedAt: DateTime.now(),
        );
        await _repo.saveEvent(master);
        added++;
      }
      if (r.uid != null) mastersByUid[r.uid!] = master;

      // Cancelled occurrences of this series.
      for (final ex in r.exdates) {
        await _cancelOccurrence(master, ex);
      }
    }

    // Pass 2: moved occurrences.
    for (final r in read.records.where((r) => r.recurrenceId != null)) {
      final master = await _masterFor(r, mastersByUid);
      if (master == null) {
        skipped++;
        continue;
      }
      final original = r.recurrenceId!;
      if (await _repo.findOverride(master.id, original) != null) {
        skipped++;
        continue;
      }
      await _repo.saveEvent(EventModel(
        id: newId(),
        calendarId: master.calendarId,
        title: r.title,
        location: r.location,
        notes: r.notes,
        allDay: r.allDay,
        start: r.start,
        end: r.end,
        parentId: master.id,
        originalStart: original,
        reminderMinutes: r.reminders,
        updatedAt: DateTime.now(),
      ));
      added++;
    }

    return ImportReport(added: added, skipped: skipped, rulesSkipped: read.rulesSkipped);
  }

  Future<EventModel?> _findExisting(IcsRecord r) async {
    final uid = r.uid;
    if (uid != null) {
      final rows = await _repo.findByUidOrId(uid, _idFromUid(uid));
      if (rows.isNotEmpty) return rows.first;
    }
    final byTitle = await _repo.findByTitleAndStart(r.title, r.start);
    return byTitle.isEmpty ? null : byTitle.first;
  }

  Future<EventModel?> _masterFor(IcsRecord r, Map<String, EventModel> mastersByUid) async {
    final uid = r.uid;
    if (uid == null) return null;
    final known = mastersByUid[uid];
    if (known != null) return known;
    final rows = await _repo.findByUidOrId(uid, _idFromUid(uid));
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _cancelOccurrence(EventModel master, DateTime at) async {
    if (await _repo.findOverride(master.id, at) != null) return;
    await _repo.saveEvent(EventModel(
      id: newId(),
      calendarId: master.calendarId,
      title: master.title,
      start: at,
      end: at.add(master.end.difference(master.start)),
      allDay: master.allDay,
      parentId: master.id,
      originalStart: at,
      isCancelled: true,
      updatedAt: DateTime.now(),
    ));
  }

  /// ChronoSync writes UIDs as "<id>@chronosync", so the id can be read back.
  static String? _idFromUid(String uid) =>
      uid.endsWith(_uidSuffix) ? uid.substring(0, uid.length - _uidSuffix.length) : null;
}
