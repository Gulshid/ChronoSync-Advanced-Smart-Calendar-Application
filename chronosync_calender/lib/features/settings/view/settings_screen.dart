import 'package:flutter/material.dart';

import 'package:chronosync_calender/core/theme/app_theme.dart';
import 'package:chronosync_calender/core/l10n/strings.dart';
import 'package:chronosync_calender/data/services/notification_service.dart';
import 'package:chronosync_calender/data/services/app_settings.dart';
import 'package:chronosync_calender/features/data_tools/view/data_tools_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _reminderChoices = [-1, 0, 5, 10, 15, 30, 60, 1440];

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(Strings.t('settings_title'))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xl),
            children: [
              _Group(
                title: Strings.t('set_appearance'),
                children: [
                  _Label(Strings.t('set_theme')),
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: ThemeMode.system, label: Text(Strings.t('theme_system'))),
                      ButtonSegment(value: ThemeMode.light, label: Text(Strings.t('theme_light'))),
                      ButtonSegment(value: ThemeMode.dark, label: Text(Strings.t('theme_dark'))),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (s) => settings.setThemeMode(s.first),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _Label(Strings.t('set_text')),
                  SegmentedButton<double>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 1.0, label: Text(Strings.t('text_normal'))),
                      ButtonSegment(value: 1.15, label: Text(Strings.t('text_large'))),
                      ButtonSegment(value: 1.3, label: Text(Strings.t('text_xlarge'))),
                    ],
                    selected: {settings.textScale},
                    onSelectionChanged: (s) => settings.setTextScale(s.first),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              _Group(
                title: Strings.t('set_language'),
                children: [
                  Wrap(
                    spacing: AppSpace.sm,
                    children: [
                      ChoiceChip(
                        label: Text(Strings.t('lang_en')),
                        selected: settings.language == 'en',
                        onSelected: (_) => settings.setLanguage('en'),
                      ),
                      ChoiceChip(
                        label: Text(Strings.t('lang_ur')),
                        selected: settings.language == 'ur',
                        onSelected: (_) => settings.setLanguage('ur'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              _Group(
                title: Strings.t('set_time'),
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(Strings.t('set_24h')),
                    value: settings.use24Hour,
                    onChanged: (v) => settings.setUse24Hour(v),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  _Label(Strings.t('set_week')),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: DateTime.monday, label: Text(Strings.t('week_mon'))),
                      ButtonSegment(value: DateTime.sunday, label: Text(Strings.t('week_sun'))),
                    ],
                    selected: {settings.weekStart},
                    onSelectionChanged: (s) => settings.setWeekStart(s.first),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              _Group(
                title: Strings.t('data_title'),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.import_export),
                    title: Text(Strings.t('data_title')),
                    subtitle: Text(Strings.t('data_subtitle')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const DataToolsScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              _Group(
                title: Strings.t('set_reminders'),
                children: [
                  _Label(Strings.t('set_default_rem')),
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: [
                      for (final m in _reminderChoices)
                        ChoiceChip(
                          label: Text(m < 0 ? Strings.t('set_rem_none') : Strings.leadLabel(m)),
                          selected: settings.defaultReminder == m,
                          onSelected: (_) => settings.setDefaultReminder(m),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await NotificationService.instance.requestPermissions();
                      messenger.showSnackBar(SnackBar(content: Text(Strings.t('set_notif_done'))));
                    },
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(Strings.t('set_notif_enable')),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpace.sm),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );
}
