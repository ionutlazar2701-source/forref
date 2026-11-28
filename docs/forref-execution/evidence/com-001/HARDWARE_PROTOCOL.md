# COM-001 Bip 6 protocol

State: **NOT TESTED**. Fill every row on a physical Amazfit Bip 6 with the phone debug bridge. Unit tests do not certify the handshake. Do not mark Level 2 from this file until every row has a copied log.

App id `29566`, version `1.0.24` (code 24), boot `build=com-002r-link rev=63bf267d3031941b443f86473187903f3008627f`. Install `dist/29566-FORREF-1.0.24-20261128084201.zab`. Do not install `1.0.20` or `1.0.21`. `1.0.23` opened and returned PONG on one LINK visit and after a full close, then returned DOWN after Back → Settings → LINK. PROVISION on that stale object showed BUSY / UNAVAILABLE. `1.0.24` keeps the direct `App({...})` registration. `app.bin` has no `createConnect` and no `disConnect`. The LINK page bundle has both. The QR is in `TEST_RESULTS.md`. It expires 10:42 Europe/Bucharest on 5 December 2026. Open FORREF and stay on Home. A reboot on open fails the trial. If Home stays up, open SETTINGS → LINK. READY must be on screen before PING, with `page=init` and `page=build`. Tap PING twice with the Zepp app running on the paired phone. Leave and return, then repeat. Turn Bluetooth off and on and tap PING again. Copy every `FORREF_LINK` line. Two `tx=connect` lines for one tap fails the trial. `tx=recover reason=close` means the old socket was kept and no replacement was opened. Do not tap PROVISION until PING, LINK-NAV, and LINK-BT have copied PONG logs. Do not lock, activate, or replicate a sporting event in this package.

## Phone debug install

The Watch provision controls are compiled only when `kDebugMode` is true. A release or profile install hides them. The release manifest does not grant `INTERNET`. This cloud image has no Android SDK, so the debug app is built on the Windows machine that already lists the phone.

On that machine, from the repository:

```
git fetch origin cursor/com-001-transport-4ae8
git checkout cursor/com-001-transport-4ae8
git pull origin cursor/com-001-transport-4ae8
cd apps\referee_phone
flutter run -d RZCY11BDMTX
```

`flutter run` with no `--release` and no `--profile` is the debug build. The phone must show the DEBUG banner. Launcher name: `referee_phone`. Application id: `com.refapp.referee_phone`.

This replaces an existing debug install signed by the same Windows debug keystore and keeps the application support directory, including saved matches and `forref_watch_provision_correlation_v1.json`. Do not uninstall first. If Android reports `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, the installed package was signed by a different key. Stop there. Uninstalling deletes the local match data.

On the matches screen, open Settings. The page shows Watch provision, the field Watch installation UUID, No saved match selected, and Prepare and listen. Enter the 36-character watch UUID, choose one saved match whose home and away names are filled in, then tap Prepare and listen. The status line begins with `listening` and the content hash. The bridge is `127.0.0.1:47221/watch-provision/v1` on that phone. The Zepp app must be on the same phone. Leave the `flutter run` terminal open.

This is the Android-local debug route only: Flutter debug bridge on `127.0.0.1:47221`, path `/watch-provision/v1`, then the Zepp Side Service, then the watch page. It is not a production transport. An active match must not need this link. Goal capture stays on the watch. This protocol does not enable Goal-to-phone replication.

## What to copy

From the watch console and the phone debug console, copy the `FORREF_PROVISION` lines for the trial. Each line is one of `tx=request`, `tx=response`, `tx=transition`, `tx=recover`. Keep `installation`, `request`, `match`, `hash`, `generation`, `http`, `disposition`, and `reason`.

Do not paste the canonical document or the team names. After the trial, record three facts in the Result column:

- Phone root: absent, or the one device id.
- Watch admission: the state named by the page or the last `tx=transition`.
- Correlation: the request id, and whether a retry used that same id.

A line with `disposition=prepared`, `locked`, or `recorded` while `http` is not 200, or while `durable` is true on a prepared or recorded body, fails the trial. A second authority root fails the trial. A new request id on a retry of the same watch and match fails the trial.

## Trial matrix

| Test | Steps | Pass | Result |
| --- | --- | --- | --- |
| BOOT | Install `1.0.24` and open FORREF from the app list. Leave it on Home for a few seconds. | Home shows OFFICIATE, TRAINING, and SETTINGS. The watch does not reboot. The boot log contains `FORREF_APP onCreate` and `build=com-002r-link`. | NOT TESTED |
| UUID | From Home, open SETTINGS, then PROVISION. Do this before any PING. Do not tap Provision. | Both UUID lines are visible. Joined, they are 36 characters. Back returns to Settings, and Back again returns to Home. OFFICIATE and TRAINING are still on Home. The installation id matches the earlier package. | NOT TESTED |
| LINK-OPEN | From Settings, open LINK. Do not tap PING yet. | The page shows READY. The log contains `page=init` and `page=build`. The watch does not reboot. Back logs `page=destroy` and `tx=retire`. | NOT TESTED |
| PING | With the Zepp app open on the paired phone, tap PING. Tap it again. | The first tap logs `tx=connect` once, then `tx=ping` and `tx=pong` with the same sequence. The second tap logs `tx=reuse` and the next sequence. The page shows PONG. The watch does not reboot. | NOT TESTED |
| LINK-NAV | From LINK, go Back to Settings, open LINK again, and tap PING. Repeat once. | Each return logs `page=destroy` and `tx=retire`, then one `tx=connect` and `tx=pong`. The watch does not reboot and does not relaunch FORREF. | NOT TESTED |
| LINK-BT | From LINK, turn Bluetooth off, turn it back on, return to LINK, and tap PING. | The tap logs one replacement or one reuse, then `tx=pong` for its sequence. `connect=0` before the replacement is expected. The watch stays up. | NOT TESTED |
| PREPARE | Do not run this row until PING, LINK-NAV, and LINK-BT have copied PONG logs. | `1.0.24` does not send `GET_WATCH_PROVISION_V1` after LINK is left, because the visit is retired. A Provision tap is not the acceptance proof. Record the page log and stop. | NOT TESTED |
| LOCK | Leave the page on that match until the lock request returns. | `disposition=locked`, `durable` true, one phone root whose device id is the watch installation. Watch phase `activated`. Same request id as PREPARE. | NOT TESTED |
| REPORT | Stay on the page until the activation report returns. | `disposition=recorded`. Watch phase `reported`. Same request id. Still one root. `saved` and `d1Certified` stay false. | NOT TESTED |
| LOST-LOCK | After PREPARE, turn Bluetooth off before the lock response is visible, then turn it back on and open the provision page again. | The retry uses the same request id. One root. No second `phase` that goes backwards. | NOT TESTED |
| LOST-REPORT | After the watch shows activated, turn Bluetooth off before `recorded`, then reconnect and open the page again. | Watch stays activated. The retry reports `recorded` with the same request id. One root. | NOT TESTED |
| SIDE | After PREPARE, force-stop the Zepp app side and open the provision page again. | Same request id. No second root. The page does not show a prepared document for a different match. | NOT TESTED |
| BRIDGE | After LOCK, stop and start the Flutter debug process, then repeat the lock from the watch. | The phone correlation file still has the same request id. A `readBack` failure is `receipt-invalid` and `durable` false. A valid retry is `idempotent-lock` and does not insert a second root. | NOT TESTED |
| REPEAT | Send the same pending, lock, and activation again without changing the match. | Dispositions stay prepared, locked, and recorded. Request id unchanged. One root. | NOT TESTED |
| LIVE | Kick off. Turn Bluetooth off for 30 s during the half. | The clock and local goal path continue. No provision request is required to keep the half running. | NOT TESTED |

HTTP 409, HTTP 500, malformed JSON, and a contradictory body are covered by the software rows in `TEST_RESULTS.md`. They are not a substitute for the rows above.
