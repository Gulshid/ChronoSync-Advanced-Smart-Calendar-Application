# ChronoSync (Flutter, local-first)

Phases 0 to 6 of the Flutter project plan. Everything runs on the phone: no backend, no paid service.

| Phase | What it adds | Main files |
|---|---|---|
| 0 | Feature list, screens, data design | `docs/phase0/` |
| 1 | Structure, SQLite, repositories, navigation, theme | `lib/data/`, `lib/app/` |
| 2 | Month, Week, Day, Agenda views | `lib/features/calendar/` |
| 3 | Events, calendars, repeating events, Undo | `lib/features/events/`, `lib/features/calendars/`, `lib/data/recurrence/` |
| 4 | Offline reminders: several per event, rescheduled on change, tap opens the event | `lib/notifications/`, `lib/features/events/event_editor_screen.dart` |
| 5 | Quick add ("Lunch with Sara tomorrow 1pm") with preview, free-time finder, search | `lib/features/quick_add/`, `lib/features/free_time/`, `lib/features/search/` |
| 6 | Settings: theme, text size, 12/24-hour clock, week start, default reminder, English and Urdu (right-to-left) | `lib/features/settings/`, `lib/l10n/strings.dart`, `lib/state/app_settings.dart` |

## Setup

Flutter 3.27 or newer.

```bash
flutter pub get
flutter test
flutter run
```

### Android setup for reminders (Phase 4)

1. In `android/app/src/main/AndroidManifest.xml`, add these above `<application>`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

2. Inside `<application>`, add these so reminders survive a phone restart:

```xml
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    </intent-filter>
</receiver>
```

3. In `android/app/build.gradle` (or `build.gradle.kts`), enable core library desugaring, which flutter_local_notifications requires:

```groovy
android {
    compileOptions {
        coreLibraryDesugaringEnabled true
    }
}
dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
}
```

Set `minSdkVersion` to 21 or higher.

### iOS

No extra manifest steps. iOS asks for notification permission the first time the app opens, and again from Settings.

## Behaviour notes

**Reminders.** Each event can have several reminders. The app schedules the next 60 days (up to 60 notifications, the iOS limit is 64). The whole schedule is rebuilt after every change and on each launch. A tap on a reminder opens that occurrence.

**Time zones.** Reminder times are stored as absolute UTC instants, so they fire at the right moment even if the phone's zone changes.

**Quick add.** Recognised words are removed from the title: today, tonight, tomorrow, day after tomorrow, in N days, weekday names ("next Monday"), "25 Dec" or "Dec 25", times such as 3pm, 3:30 pm, 15:00, noon, midnight, all day, and durations such as "for 45 minutes". With no time given, the event starts at the next full hour. With a date but no time, it starts at 9:00 AM.

**Search** looks through titles, locations and notes, from one year before to one year after today.

**Language.** English and Urdu. Urdu switches the whole layout to right-to-left. Change it in Settings, then Language. Dates and times follow the chosen language.

## Deviations and limits

- Reminder lead times are fixed presets (none, at the start, 5 to 60 minutes, 2 hours, 1 day, 2 days, 1 week). Custom values are not offered yet.
- Snooze and dismiss buttons on notifications are not included.
- Reminders are stored in a new `events.reminders` column (database version 2). The old `reminders` table from Phase 1 is kept but unused.
- Strings are kept in `lib/l10n/strings.dart` rather than generated ARB files. Add a key to both the English and Urdu maps.
- Free-time working hours are fixed presets (9 to 5, 8 to 6, 7 to 10).
- Week start is Monday or Sunday.

## Tests

- `test/recurrence_rule_test.dart`, `test/occurrence_builder_test.dart`: recurrence (Phase 3)
- `test/overlap_layout_test.dart`: overlap layout (Phase 2)
- `test/quick_add_parser_test.dart`: quick add parsing (Phase 5)
- `test/free_time_finder_test.dart`: free-time gaps (Phase 5)

Notifications, the database and the UI need a device or emulator to test. Check that a reminder arrives with the phone in airplane mode and that a changed event moves its reminder.
