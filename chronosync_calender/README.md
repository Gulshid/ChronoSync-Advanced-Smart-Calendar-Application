# ChronoSync (Flutter, local-first)

Phases 0 to 9 of the Flutter project plan. Everything runs on the phone, except the optional Google Calendar sync (Phase 8), which talks directly to Google.

| Phase | What it adds | Main files |
|---|---|---|
| 0 | Plan, screens, data design | `docs/phase0/` |
| 1 | Structure, SQLite, repositories, navigation, theme | `lib/data/`, `lib/app/` |
| 2 | Month, Week, Day, Agenda views | `lib/features/calendar/` |
| 3 | Events, calendars, repeating events, Undo | `lib/features/events/`, `lib/features/calendars/`, `lib/data/recurrence/` |
| 4 | Offline reminders | `lib/notifications/` |
| 5 | Quick add, free time, search | `lib/features/quick_add/`, `lib/features/free_time/`, `lib/features/search/` |
| 6 | Settings, English and Urdu | `lib/features/settings/`, `lib/l10n/strings.dart` |
| 7 | Export and import .ics, backup and restore | `lib/data/ics/`, `lib/data/transfer/`, `lib/features/data_tools/` |
| 8 | Optional Google Calendar sync | `lib/sync/google_calendar_sync.dart` |
| 9 | Testing and release | `docs/phase9_release.md`, `test/` |

The Flutter plan has no Phase 10. Phase 9 is the last phase.

## Setup

Flutter 3.27 or newer.

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Earlier Android and iOS setup (reminders, notifications) is unchanged.

## Phase 7: Import, export and backup

**Export (.ics).** Data tools → Export calendars. Produces one .ics file with every calendar. Repeating events, moved occurrences, cancelled occurrences, reminders and all-day events are included. Google Calendar, Outlook and Apple Calendar can open it.

**Import (.ics).** Data tools → Import .ics file. Events already on the phone are skipped. Matching uses the UID, then the title and start time. Calendars named in the file are created if they don't exist. Time zones (TZID) are converted with the `timezone` package.

**Backup and restore.** Data tools → Back up everything saves one JSON file. Restore replaces every calendar and event with the backup, and asks for confirmation first. Restoring a backup from a newer app version is refused.

Files are shared through the system share sheet (save to Files, email, or Drive). Import and restore open the system file picker.

## Phase 8: Google Calendar sync

**What syncs:** single events and whole repeating series, from the user's primary Google calendar, from 30 days ago to one year ahead.

**What doesn't:** a change to one occurrence of a series stays on the phone where it was made. Deletions on either side are applied to the other side.

**Conflicts:** the most recent change wins.

**When it runs:** Sync now, or automatically a few seconds after a change if "Sync automatically" is on.

### One-time Google setup (required)

1. In Google Cloud Console, create a project. Enable the **Google Calendar API**.
2. Set up the **OAuth consent screen**. While the app is in testing, add each tester's Google account under "Test users".
3. Create an **OAuth client ID for Android**. Use the package name `com.example.chronosync_calender` (or your own application ID) and the SHA-1 of your signing key:
   ```bash
   keytool -list -v -keystore ~/chronosync-upload.jks -alias upload
   ```
   For a debug build, use the debug keystore (`~/.android/debug.keystore`, alias `androiddebugkey`, password `android`).
4. Create an **OAuth client ID for iOS** with your bundle ID. Copy the **REVERSED_CLIENT_ID** value shown there.
5. In `ios/Runner/Info.plist`, add a URL type using the reversed client ID. Put this inside the top-level `<dict>`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

Replace `YOUR_REVERSED_CLIENT_ID` with the value from step 4 (it looks like `com.googleusercontent.apps.123456-abc`).

6. Run `flutter clean`, then `flutter run`. Open Settings → Data and sync → Connect Google Calendar.

If sign-in fails with a "developer error" or "sign_in_failed" message on Android, the SHA-1 in step 3 doesn't match the key the app was built with.

## Phase 9: Testing and release

Run `flutter analyze` and `flutter test` before every build. The full checklist, Android signing steps, and the store checklist are in `docs/phase9_release.md`.

## Tests

- `test/recurrence_rule_test.dart`, `test/occurrence_builder_test.dart`: recurrence
- `test/overlap_layout_test.dart`: overlap layout
- `test/quick_add_parser_test.dart`: quick add
- `test/free_time_finder_test.dart`: free-time gaps
- `test/ics_codec_test.dart`, `test/ics_roundtrip_test.dart`: .ics format and round trip

Notifications, sharing, file pickers and Google sign-in need a device to test.

## Known limits

- Google sync covers single events and whole series. Changes to one occurrence stay on the phone.
- Repeat rules: DAILY, WEEKLY, MONTHLY, YEARLY, with INTERVAL, BYDAY (weekly), BYMONTHDAY, COUNT and UNTIL. Other parts are ignored.
- Reminder lead times are presets; snooze buttons are not included.
- Strings are in `lib/l10n/strings.dart`. Add each new key to both the English and Urdu maps.
