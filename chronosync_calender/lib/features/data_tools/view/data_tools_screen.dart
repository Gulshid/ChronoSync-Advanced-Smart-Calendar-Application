import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:chronosync_calender/core/app/app_services.dart';
import 'package:chronosync_calender/core/widgets/app_section.dart';
import 'package:chronosync_calender/core/utils/app_format.dart';
import 'package:chronosync_calender/core/theme/app_theme.dart';
import 'package:chronosync_calender/data/services/backup_service.dart';
import 'package:chronosync_calender/data/services/ics_export_service.dart';
import 'package:chronosync_calender/data/services/ics_import_service.dart';
import 'package:chronosync_calender/data/services/transfer_files.dart';
import 'package:chronosync_calender/core/l10n/strings.dart';
import 'package:chronosync_calender/data/services/google_calendar_sync.dart';

/// Export, import, backup, restore and Google Calendar sync (Phases 7 and 8).
class DataToolsScreen extends StatefulWidget {
  const DataToolsScreen({super.key});

  @override
  State<DataToolsScreen> createState() => _DataToolsScreenState();
}

class _DataToolsScreenState extends State<DataToolsScreen> {
  bool _busy = false;
  bool _connected = false;
  bool _autoSync = false;
  String? _email;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _refreshGoogle();
  }

  Future<void> _refreshGoogle() async {
    final sync = GoogleCalendarSync.instance;
    final connected = await sync.isConnected();
    final auto = await sync.autoSync();
    final last = await sync.lastSync();
    if (!mounted) return;
    setState(() {
      _connected = connected;
      _email = sync.accountEmail;
      _autoSync = auto;
      _lastSync = last;
    });
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _message(Strings.t('action_failed', {'error': '$error'}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Export and backup -----------------------------------------------------

  Future<void> _exportIcs() => _run(() async {
        final text = await IcsExportService.build(AppServices.transfer);
        await shareTextFile(fileName: 'chronosync.ics', content: text, subject: 'ChronoSync calendar');
      });

  Future<void> _backup() => _run(() async {
        final text = await BackupService(AppServices.transfer).create();
        await shareTextFile(fileName: 'chronosync-backup.json', content: text, subject: 'ChronoSync backup');
      });

  // Import and restore ----------------------------------------------------

  Future<void> _importIcs() => _run(() async {
        final text = await pickTextFile(['ics']);
        if (text == null) return;
        final report = await IcsImportService(AppServices.transfer).importText(text);
        await AppServices.controller.init();
        _message(Strings.t('import_result', {'added': report.added, 'skipped': report.skipped}));
      });

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(Strings.t('restore_backup')),
        content: Text(Strings.t('restore_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(Strings.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(Strings.t('restore_backup')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run(() async {
      final text = await pickTextFile(['json']);
      if (text == null) return;
      try {
        final count = await BackupService(AppServices.transfer).restore(text);
        await AppServices.controller.init();
        _message(Strings.t('restore_result', {'n': count}));
      } on FormatException {
        _message(Strings.t('backup_invalid'));
      }
    });
  }

  // Google Calendar -------------------------------------------------------

  Future<void> _connect() => _run(() async {
        final email = await GoogleCalendarSync.instance.connect();
        if (email == null) {
          _message(Strings.t('google_cancelled'));
          return;
        }
        await _refreshGoogle();
        await _syncNow();
      });

  Future<void> _syncNow() => _run(() async {
        final report = await GoogleCalendarSync.instance.syncNow(AppServices.transfer);
        await AppServices.controller.init();
        await _refreshGoogle();
        final summary = Strings.t('google_result', {
          'pulled': report.pulled,
          'pushed': report.pushed,
          'removed': report.removed,
        });
        _message(report.failed > 0 ? '$summary ${Strings.t('google_failed', {'n': report.failed})}' : summary);
      });

  Future<void> _disconnect() => _run(() async {
        await GoogleCalendarSync.instance.disconnect();
        await _refreshGoogle();
      });

  Future<void> _toggleAuto(bool on) async {
    await GoogleCalendarSync.instance.setAutoSync(on);
    if (mounted) setState(() => _autoSync = on);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final last = _lastSync;

    return Scaffold(
      appBar: AppBar(title: Text(Strings.t('data_title'))),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xl),
              children: [
                AppSection(
                  title: Strings.t('data_sec_export'),
                  icon: Icons.upload_file_outlined,
                  children: [
                    _Action(
                      icon: Icons.event_note_outlined,
                      title: Strings.t('export_ics'),
                      subtitle: Strings.t('export_ics_sub'),
                      onTap: _busy ? null : _exportIcs,
                    ),
                    _Action(
                      icon: Icons.archive_outlined,
                      title: Strings.t('backup_create'),
                      subtitle: Strings.t('backup_create_sub'),
                      onTap: _busy ? null : _backup,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
                AppSection(
                  title: Strings.t('data_sec_import'),
                  icon: Icons.download_outlined,
                  children: [
                    _Action(
                      icon: Icons.file_open_outlined,
                      title: Strings.t('import_ics'),
                      subtitle: Strings.t('import_ics_sub'),
                      onTap: _busy ? null : _importIcs,
                    ),
                    _Action(
                      icon: Icons.settings_backup_restore,
                      title: Strings.t('restore_backup'),
                      subtitle: Strings.t('restore_backup_sub'),
                      onTap: _busy ? null : _restore,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
                AppSection(
                  title: Strings.t('data_sec_google'),
                  icon: Icons.cloud_outlined,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: IconBadge(icon: _connected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined),
                      title: Text(
                        _connected ? (_email ?? '') : Strings.t('google_signed_out'),
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text(
                        last == null
                            ? Strings.t('google_never')
                            : Strings.t('google_last', {'time': '${DateFormat.yMMMd().format(last)} ${AppFormat.time(last)}'}),
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      Strings.t('google_help'),
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Wrap(
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.sm,
                      children: _connected
                          ? <Widget>[
                              FilledButton.tonalIcon(
                                onPressed: _busy ? null : _syncNow,
                                icon: const Icon(Icons.sync),
                                label: Text(Strings.t('google_sync_now')),
                              ),
                              OutlinedButton(
                                onPressed: _busy ? null : _disconnect,
                                child: Text(Strings.t('google_disconnect')),
                              ),
                            ]
                          : <Widget>[
                              FilledButton.icon(
                                onPressed: _busy ? null : _connect,
                                icon: const Icon(Icons.login),
                                label: Text(Strings.t('google_connect')),
                              ),
                            ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(Strings.t('google_auto')),
                      value: _autoSync,
                      onChanged: _connected && !_busy ? _toggleAuto : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable row with an icon badge, used for each data action.
class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: IconBadge(icon: icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.chevron_right, color: onTap == null ? cs.outline : cs.onSurfaceVariant),
      enabled: onTap != null,
      onTap: onTap,
    );
  }
}
