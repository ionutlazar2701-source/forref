# MOBILE 003 — Android baseline and configuration payload

Branch: `cursor/forref-mobile-003-android-sync`

Start: `69c966251864ec53bbc59904e8e86a08f8057a6b` on `cursor/forref-mobile-002v-visual-system`.

## Android baseline

The phone app is the existing Flutter shell. Application id: `com.refapp.referee_phone`. Minimum Android version: 7.0 (API 24).

A debug build writes `apps/referee_phone/build/app/outputs/flutter-apk/app-debug.apk`. That file is not committed. Installing it and repeating the persistence path on a physical Android phone is **LOCAL GATE REQUIRED**.

Team names, competition, venue, half length, and crew are written to local SQLite (`ref_app_matches` under the app support directory) as the preparation fields change. There is no separate Save button.

### Physical persistence test

On the phone:

1. Settings → About phone → tap Build number seven times.
2. Settings → Developer options → turn on USB debugging.
3. Connect the phone by USB. When the phone asks, allow USB debugging for this computer.

On the Windows machine that has this repository, Flutter, a JDK, the Android SDK, and `adb` on `PATH`:

```powershell
cd .\apps\referee_phone
flutter build apk --debug
adb devices
adb install -r .\build\app\outputs\flutter-apk\app-debug.apk
```

`adb devices` must list the phone as `device`. `unauthorized` means the phone prompt was not accepted.

On the phone:

1. Open FORREF.
2. Create a match.
3. Enter a home team name and an away team name. Optional: competition, venue, crew. Leave half length at a positive number of minutes.
4. Wait one second after the last character so the local write finishes.
5. Close the app completely (swipe it away from Recents, or Settings → Apps → FORREF → Force stop).
6. Open FORREF again.
7. The same match must still be listed, and opening it must show the same team names.

Pass only if step 7 matches what was typed. Cloud execution cannot mark this pass.

## Configuration payload

`MatchConfigurationPayload` version 1 is a projection of configuration already stored on the legacy match document: fixture identity, teams, half length, extra-time settings, and crew names.

It does not include score, events, status, or sync state. It is not a Match Record and it is not sent to a watch. Watch synchronization is a separate gate.
