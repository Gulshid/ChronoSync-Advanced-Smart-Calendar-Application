import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/id_generator.dart';
import '../data/models/event_model.dart';
import '../data/recurrence/recurrence_rule.dart';
import '../data/repositories/transfer_repository.dart';

class SyncReport {
  const SyncReport({required this.pulled, required this.pushed, required this.removed, required this.failed});

  final int pulled;
  final int pushed;
  final int removed;
  final int failed;
}

/// Two-way sync with the user's primary Google calendar (Phase 8).
///
/// Synced: single events and whole recurring series.
/// Not synced: changes to one occurrence of a series, which stay on this phone.
/// Conflicts: the change made most recently wins.
class GoogleCalendarSync {
  GoogleCalendarSync._();

  static final GoogleCalendarSync instance = GoogleCalendarSync._();

  final GoogleSignIn _signIn = GoogleSignIn(scopes: [gcal.CalendarApi.calendarEventsScope]);

  Timer? _debounce;

  static const _knownKey = 'google_known_ids';
  static const _lastKey = 'google_last_sync_ms';
  static const _autoKey = 'google_auto_sync';

  Future<bool> isConnected() => _signIn.isSignedIn();

  String? get accountEmail => _signIn.currentUser?.email;

  /// Returns the connected email, or null if the user cancelled.
  Future<String?> connect() async {
    final account = await _signIn.signIn();
    return account?.email;
  }

  Future<void> disconnect() async {
    await _signIn.disconnect();
  }

  Future<bool> autoSync() async => (await SharedPreferences.getInstance()).getBool(_autoKey) ?? false;

  Future<void> setAutoSync(bool on) async {
    await (await SharedPreferences.getInstance()).setBool(_autoKey, on);
  }

  Future<DateTime?> lastSync() async {
    final ms = (await SharedPreferences.getInstance()).getInt(_lastKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Runs a sync a few seconds after the last local change, when auto-sync is on and the account is connected.
  void scheduleAutoSync(TransferRepository repo, Future<void> Function() onDone) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 5), () async {
      if (!await autoSync() || !await isConnected()) return;
      try {
        await syncNow(repo);
        await onDone();
      } catch (_) {
        // The Data and sync screen shows the error the next time it is opened.
      }
    });
  }

  Future<SyncReport> syncNow(TransferRepository repo) async {
    final client = await _signIn.authenticatedClient();
    if (client == null) throw StateError('Not connected to Google.');

    try {
      final api = gcal.CalendarApi(client);
      final now = DateTime.now();
      final remote = await _listRemote(api, now.subtract(const Duration(days: 30)), now.add(const Duration(days: 365)));

      final prefs = await SharedPreferences.getInstance();
      final known = (jsonDecode(prefs.getString(_knownKey) ?? '[]') as List).cast<String>().toSet();

      final calendars = await repo.calendars();
      final defaultCalendar = calendars.firstWhere((c) => c.isDefault, orElse: () => calendars.first);

      final remoteIds = <String>{};
      final cancelledIds = <String>{};
      var pulled = 0;
      var pushed = 0;
      var removed = 0;
      var failed = 0;

      // Local rows keyed by Google id, as they were before this sync.
      final localByGoogle = <String, EventModel>{};
      for (final e in await repo.syncableEvents()) {
        final gid = e.googleId;
        if (gid != null) localByGoogle.putIfAbsent(gid, () => e);
      }

      // Step 1: pull changes from Google.
      for (final g in remote) {
        final gid = g.id;
        if (gid == null) continue;
        remoteIds.add(gid);
        final local = localByGoogle[gid];

        if (g.status == 'cancelled') {
          cancelledIds.add(gid);
          if (local != null) {
            await repo.deleteEvent(local.id);
            removed++;
          }
          continue;
        }

        if (local == null) {
          // Deleted on this phone: the deletion is pushed in step 2.
          if (known.contains(gid)) continue;
          await repo.saveEvent(_fromGoogle(g, id: newId(), gid: gid, calendarId: defaultCalendar.id));
          pulled++;
          continue;
        }

        final remoteUpdated = g.updated?.toLocal();
        if (remoteUpdated != null && remoteUpdated.isAfter(local.updatedAt)) {
          await repo.saveEvent(_fromGoogle(
            g,
            id: local.id,
            gid: gid,
            calendarId: local.calendarId,
            updated: remoteUpdated,
            colorValue: local.colorValue,
          ));
          pulled++;
        }
      }

      // Step 2: push deletions made on this phone.
      for (final gid in known) {
        if (localByGoogle.containsKey(gid) || cancelledIds.contains(gid) || !remoteIds.contains(gid)) continue;
        try {
          await api.events.delete('primary', gid);
          removed++;
        } catch (_) {
          failed++;
        }
      }

      // Step 3: push local changes. Re-read so rows pulled in step 1 are not sent back.
      final seen = <String>{};
      for (final e in await repo.syncableEvents()) {
        final gid = e.googleId;
        final duplicate = gid != null && !seen.add(gid);
        final synced = e.googleSyncedMs;
        final needsPush = gid == null ||
            duplicate ||
            synced == null ||
            e.updatedAt.millisecondsSinceEpoch > synced;
        if (!needsPush) continue;

        final id = (gid == null || duplicate) ? _googleIdFor(e.id) : gid;
        final body = _toGoogle(e, id);
        try {
          final gcal.Event result;
          if (gid != null && !duplicate && remoteIds.contains(gid)) {
            result = await api.events.update(body, 'primary', id);
          } else {
            result = await api.events.insert(body, 'primary');
          }
          await repo.markSynced(
            e.id,
            googleId: result.id ?? id,
            syncedAt: result.updated?.toLocal() ?? DateTime.now(),
          );
          pushed++;
        } catch (_) {
          failed++;
        }
      }

      final linked = await repo.syncableGoogleIds();
      await prefs.setString(_knownKey, jsonEncode(linked.toList()));
      await prefs.setInt(_lastKey, DateTime.now().millisecondsSinceEpoch);
      return SyncReport(pulled: pulled, pushed: pushed, removed: removed, failed: failed);
    } finally {
      client.close();
    }
  }

  Future<List<gcal.Event>> _listRemote(gcal.CalendarApi api, DateTime from, DateTime to) async {
    final out = <gcal.Event>[];
    String? token;
    do {
      final page = await api.events.list(
        'primary',
        timeMin: from.toUtc(),
        timeMax: to.toUtc(),
        singleEvents: false,
        showDeleted: true,
        maxResults: 250,
        pageToken: token,
      );
      out.addAll(page.items ?? const []);
      token = page.nextPageToken;
    } while (token != null);
    return out;
  }

  /// Google event ids may only use a-v and 0-9. Hex encoding of our id meets that rule.
  static String _googleIdFor(String localId) =>
      'cs${localId.codeUnits.map((c) => c.toRadixString(16).padLeft(2, '0')).join()}';

  static gcal.Event _toGoogle(EventModel e, String googleId) {
    final event = gcal.Event()
      ..id = googleId
      ..summary = e.title
      ..location = e.location
      ..description = e.notes
      ..start = e.allDay
          ? gcal.EventDateTime(date: DateTime.utc(e.start.year, e.start.month, e.start.day))
          : gcal.EventDateTime(dateTime: e.start.toUtc())
      ..end = e.allDay
          ? gcal.EventDateTime(date: DateTime.utc(e.end.year, e.end.month, e.end.day))
          : gcal.EventDateTime(dateTime: e.end.toUtc())
      ..reminders = gcal.EventReminders(
        useDefault: false,
        overrides: [for (final m in e.reminderMinutes) gcal.EventReminder(method: 'popup', minutes: m)],
      );
    if (e.rrule != null) event.recurrence = ['RRULE:${e.rrule}'];
    return event;
  }

  static EventModel _fromGoogle(
    gcal.Event g, {
    required String id,
    required String gid,
    required String calendarId,
    DateTime? updated,
    int? colorValue,
  }) {
    final now = DateTime.now();
    final startDate = g.start?.date;
    final endDate = g.end?.date;
    final allDay = startDate != null;

    final start = startDate != null
        ? DateTime(startDate.year, startDate.month, startDate.day)
        : (g.start?.dateTime?.toLocal() ?? now);
    final end = endDate != null
        ? DateTime(endDate.year, endDate.month, endDate.day)
        : (allDay ? start.add(const Duration(days: 1)) : (g.end?.dateTime?.toLocal() ?? start.add(const Duration(hours: 1))));

    String? rrule;
    final ruleLine = g.recurrence?.firstWhere((r) => r.startsWith('RRULE:'), orElse: () => '') ?? '';
    if (ruleLine.isNotEmpty) {
      final raw = ruleLine.substring('RRULE:'.length);
      try {
        RecurrenceRule.parse(raw);
        rrule = raw;
      } on FormatException {
        rrule = null;
      }
    }

    final stamp = updated ?? g.updated?.toLocal() ?? now;
    return EventModel(
      id: id,
      calendarId: calendarId,
      title: g.summary ?? '',
      location: g.location ?? '',
      notes: g.description ?? '',
      colorValue: colorValue,
      allDay: allDay,
      start: start,
      end: end,
      rrule: rrule,
      reminderMinutes: [
        for (final r in g.reminders?.overrides ?? const <gcal.EventReminder>[])
          if (r.minutes != null) r.minutes!,
      ],
      googleId: gid,
      googleSyncedMs: stamp.millisecondsSinceEpoch,
      updatedAt: stamp,
    );
  }
}
