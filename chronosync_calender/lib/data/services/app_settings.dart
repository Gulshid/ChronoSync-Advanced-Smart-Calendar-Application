import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chronosync_calender/core/utils/app_format.dart';
import 'package:chronosync_calender/core/l10n/strings.dart';

/// User preferences (Phase 6). Saved with shared_preferences and applied globally.
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  ThemeMode _themeMode = ThemeMode.system;
  String _language = 'en';
  double _textScale = 1.0;
  bool _use24Hour = false;
  int _weekStart = DateTime.monday;

  /// Minutes before an event. -1 means no default reminder.
  int _defaultReminder = 10;

  ThemeMode get themeMode => _themeMode;
  String get language => _language;
  Locale get locale => Locale(_language);
  double get textScale => _textScale;
  bool get use24Hour => _use24Hour;
  int get weekStart => _weekStart;
  int get defaultReminder => _defaultReminder;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values.byName(p.getString('theme') ?? 'system');
    _language = p.getString('language') ?? 'en';
    _textScale = p.getDouble('text_scale') ?? 1.0;
    _use24Hour = p.getBool('use24h') ?? false;
    _weekStart = p.getInt('week_start') ?? DateTime.monday;
    _defaultReminder = p.getInt('default_reminder') ?? 10;
    _apply();
  }

  void _apply() {
    AppFormat.use24Hour = _use24Hour;
    Strings.lang = _language;
    Intl.defaultLocale = _language;
  }

  Future<void> _update(void Function() change, Future<bool> Function(SharedPreferences p) write) async {
    change();
    _apply();
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await write(p);
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _update(() => _themeMode = mode, (p) => p.setString('theme', mode.name));

  Future<void> setLanguage(String code) =>
      _update(() => _language = code, (p) => p.setString('language', code));

  Future<void> setTextScale(double scale) =>
      _update(() => _textScale = scale, (p) => p.setDouble('text_scale', scale));

  Future<void> setUse24Hour(bool value) =>
      _update(() => _use24Hour = value, (p) => p.setBool('use24h', value));

  Future<void> setWeekStart(int weekday) =>
      _update(() => _weekStart = weekday, (p) => p.setInt('week_start', weekday));

  Future<void> setDefaultReminder(int minutes) =>
      _update(() => _defaultReminder = minutes, (p) => p.setInt('default_reminder', minutes));
}
