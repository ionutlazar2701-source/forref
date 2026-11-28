# COM-001 Bip 6 protocol

State: **SIDE PARITY NOT TESTED. LOCK DISABLED**. On `1.0.27` the page showed `fetch:transport`. A Zepp JS App Log contained minified Side Service source with `tx=recover method=`. That string is the `1.0.25` side catch. The painted `fetch:transport` is a `1.0.26` or `1.0.27` reply. Those two observations were not shown to be one running bundle. On `1.0.26` the founder reported the phone status `listening`, then CONFIG PREGĂTIT on the first Provision tap, then CONFIG PREGĂTIT again after Back → PROVISION → Provision. No console log was attached, so the installation UUID, request UUID, match id, and content hash were not compared. Those rows are not certified. Unit tests do not certify the Bip 6. Do not mark Level 2 from this file.

App id `29566`, version `1.0.28` (code 28), boot `build=com-004r-parity rev=64f3f2b89e4d8edee1d37d7b961537be8c75888e`. Install `dist/29566-FORREF-1.0.28-20261128112329.zab`. Do not install `1.0.20` or `1.0.21`. Do not uninstall the Zepp app, FORREF Mobile, or FORREF Watch. Do not clear the watch UUID, the correlation file, or a prepared match. `app.bin` has no `createConnect` and no `GET_WATCH_PROVISION`. `app-side.js` contains `tx=side-build` and does not contain `tx=recover method=`. The PROVISION page bundle contains `runSideDiagnostic`, `GET_SIDE_BUILD`, and `PROBE_BRIDGE`. The QR is in `TEST_RESULTS.md`. It expires 13:23 Europe/Bucharest on 5 December 2026.

The Side Service runs in the Zepp phone app. A new preview updates the watch app when the version code increases and delivers a new side bundle to the phone. A Side Service that is already running keeps its loaded JavaScript until the Zepp process is destroyed. After installing `1.0.28`, force-stop Zepp from Android Settings, then open Zepp again. Open FORREF and stay on Home. A reboot on open fails the trial. Home → SETTINGS → PROVISION shows the UUID before any tap and logs `tx=device-build` without sending a request. Tap Provision once. The first side answer is `GET_SIDE_BUILD_V1` and does not use HTTP. Copy `tx=parity`. `match=1` means both sides logged `build=com-004r-parity`, `rev=64f3f2b89e4d8edee1d37d7b961537be8c75888e`, `version=1.0.28`, and `code=28`. `match=0` means the live side is not this package. Stop, force-stop Zepp again, and repeat. Do not create a match to obtain a pass. After `match=1` the same tap sends `PROBE_BRIDGE_V1`. The side POSTs `{"operation":"probe"}`. Copy `tx=probe`, including `name`, `code`, `error`, `http`, and `reason`. The phone refuses that body before it writes a match or an authority root. Lock and activation are refused before fetch on this build.

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

On the matches screen, open Settings. The page shows Watch provision, the field Watch installation UUID, No saved match selected, Prepare and listen, Inspect provision, and Cancel prepared. Enter the 36-character watch UUID, choose one saved match whose home and away names are filled in, then tap Prepare and listen. The status line begins with `listening` and the content hash. If it is `prepared-conflict`, tap Inspect provision. The line names `changed=content-hash`, `writer-device`, `principal`, or `none`, plus `root=` and `records=`, and the stored hash, writer, and principal. It does not include the canonical document. Tap Cancel prepared to remove that `CONFIG_PREPARED` row through `cancelPreparedWatchMatch`, using the stored hash. Cancellation is refused when the stage is not `CONFIG_PREPARED`, the hash does not match, a generation-1 root exists, or a sporting record exists. Those refusals leave the root and the match history in place. After `cancelled`, tap Prepare and listen again. The bridge is `127.0.0.1:47221/watch-provision/v1` on that phone. The Zepp app must be on the same phone. Leave the `flutter run` terminal open.

This is the Android-local debug route only: Flutter debug bridge on `127.0.0.1:47221`, path `/watch-provision/v1`, then the Zepp Side Service, then the watch page. It is not a production transport. An active match must not need this link. Goal capture stays on the watch. This protocol does not enable Goal-to-phone replication.

## What to copy

From the watch console and the phone debug console, copy the `FORREF_PROVISION` lines for the trial. Each line is one of `tx=request`, `tx=side`, `tx=fetch`, `tx=bridge`, `tx=normalize`, `tx=response`, `tx=transition`, `tx=recover`. Keep `hop`, `category`, `elapsed`, `installation`, `request`, `match`, `hash`, `generation`, `http`, `disposition`, and `reason`.

Do not paste the canonical document or the team names. After the trial, record three facts in the Result column:

- Phone root: absent, or the one device id.
- Watch admission: the state named by the page or the last `tx=transition`.
- Correlation: the request id, and whether a retry used that same id.

A line with `disposition=prepared`, `locked`, or `recorded` while `http` is not 200, or while `durable` is true on a prepared or recorded body, fails the trial. A second authority root fails the trial. A new request id on a retry of the same watch and match fails the trial.

## Trial matrix

| Test | Steps | Pass | Result |
| --- | --- | --- | --- |
| BOOT | Install `1.0.28` and open FORREF from the app list. Leave it on Home for a few seconds. | Home shows OFFICIATE, TRAINING, and SETTINGS. The watch does not reboot. The boot log contains `FORREF_APP onCreate` and `build=com-004r-parity`. | NOT TESTED |
| UUID | From Home, open SETTINGS, then PROVISION. Do not tap Provision yet. | Both UUID lines are visible. Joined, they are 36 characters. Back returns to Settings. The id matches the phone field. `tx=device-build` names `version=1.0.28` and `code=28`. No `tx=probe` was logged on this open. | NOT TESTED |
| PING | `1.0.24` on the Bip 6. Repeated PING on one LINK visit. | Founder reported PONG. No console excerpt was attached. | FOUNDER REPORTED PASS |
| LINK-NAV | `1.0.24`. LINK → Back → LINK → PING. | Founder reported PONG. No console excerpt was attached. | FOUNDER REPORTED PASS |
| LINK-BT | `1.0.24`. Bluetooth off, then on, then PING. | Founder reported PONG. No console excerpt was attached. | FOUNDER REPORTED PASS |
| PREPARE-UI | `1.0.25`. Tap Provision with Bluetooth connected, with Bluetooth disabled, and after reconnect. | Founder reported `unavailable`, then `messaging`, then `unavailable`. A new phone match returned `listening`. An older prepared match returned `prepared-conflict`. No console excerpt was attached. | FOUNDER REPORTED |
| PREPARE | On `1.0.26`, with the phone listening for this UUID and one saved match, tap Provision. | The page showed CONFIG PREGĂTIT. The phone had already shown `listening`. No console excerpt was attached, so the request id, match id, and content hash were not compared. | FOUNDER REPORTED VISUAL |
| PREPARE-HOP | On `1.0.26`, if the page is not CONFIG PREPARED, copy the status and the `hop` line. | The status names one hop: `device:messaging` when Bluetooth is off, `fetch:timeout`, `fetch:connection-refused`, `fetch:permission`, `fetch:transport`, `bridge:` plus the phone reason, or `normalize:malformed`. The log has `elapsed` on `tx=fetch` and does not contain the canonical document. | NOT TESTED |
| PREPARE-CONFLICT | On the phone, open a match that already shows `prepared-conflict`. Tap Inspect provision, then Cancel prepared, then Prepare and listen. | Inspect names the changed field among `content-hash`, `writer-device`, and `principal`. Cancel returns `cancelled` only for `CONFIG_PREPARED` with the stored hash, no generation-1 root, and no sporting record. The same match then returns `listening`. A root or a sporting record stays in place. | NOT TESTED |
| PREPARE-NAV | On `1.0.26`, Back → PROVISION → Provision. | The page showed CONFIG PREGĂTIT again. No console excerpt was attached, so this is not proof that the request id and content hash stayed the same. | FOUNDER REPORTED VISUAL |
| EVIDENCE | On `1.0.27`, open PROVISION and do not tap. On the phone, tap Inspect provision for the same match. | `tx=evidence` names the same installation, request, match, and hash as the phone line, `generation=1`, `canonical=accepted`, `readback=1`, `lock=0`, and `activation=0`. Phone `root=absent`. Neither line contains the canonical document. No new match was created. | NOT TESTED |
| SIDE-SOURCE | On `1.0.27`, compare the page status with the Zepp JS App Log source. | The page showed `fetch:transport`. The log source contained `tx=recover method=`, the `1.0.25` side catch. Those were not shown to be one running process. | REPORTED, NOT CORRELATED |
| PARITY | On `1.0.28`, force-stop Zepp without uninstalling it, open Zepp, open PROVISION, and tap once. | `tx=device-build` and `tx=side-build` name the same `build`, `rev`, `version`, and `code`. `tx=parity match=1`. No HTTP line appears before that parity line. The UUID and correlation file are unchanged. | NOT TESTED |
| STALE | If parity is not `match=1`. | The live side answered `reason=method` or a different build id. No `tx=probe`. Force-stop Zepp and repeat PARITY. Do not clear the watch files. | NOT TESTED |
| PROBE | The same `1.0.28` tap, after `match=1`. | `tx=probe` keeps `http`, `reason`, and, when fetch throws, `name`, `code`, and the original `error` text. The posted body is `{"operation":"probe"}`. The phone root, correlation file, and prepared stage are unchanged. | NOT TESTED |
| LOCK | This `1.0.28` tap. | The log has no `SUBMIT_WATCH_LOCK_V1` and no `REPORT_WATCH_ACTIVATED_V1`. A lock or activation method is refused `prepare-only` before fetch. Authority is not committed. The successful lock trial waits for a later build. | NOT TESTED |
| REPORT | This `1.0.28` tap. | No activation report is sent. Phone phase is unchanged. `saved` and `d1Certified` stay false. Match history is unchanged. | NOT TESTED |
| LOST-LOCK | After a later build enables lock, turn Bluetooth off before the lock response is visible, then turn it back on and open the provision page again. | The retry uses the same request id. One root. No second `phase` that goes backwards. | NOT THIS BUILD |
| LOST-REPORT | After the watch shows activated on that later build, turn Bluetooth off before `recorded`, then reconnect and open the page again. | Watch stays activated. The retry reports `recorded` with the same request id. One root. | NOT THIS BUILD |
| SIDE | After prepare on that later build, force-stop the Zepp app and open the provision page again. | Same request id. No second root. The page does not show a prepared document for a different match. | NOT THIS BUILD |
| BRIDGE | After lock on that later build, stop and start the Flutter debug process, then repeat the lock from the watch. | The phone correlation file still has the same request id. A `readBack` failure is `receipt-invalid` and `durable` false. A valid retry is `idempotent-lock` and does not insert a second root. | NOT THIS BUILD |
| REPEAT | Send the same pending, lock, and activation again without changing the match. | Dispositions stay prepared, locked, and recorded. Request id unchanged. One root. | NOT THIS BUILD |
| LIVE | Kick off. Turn Bluetooth off for 30 s during the half. | The clock and local goal path continue. No provision request is required to keep the half running. | NOT TESTED |

HTTP 409, HTTP 500, malformed JSON, and a contradictory body are covered by the software rows in `TEST_RESULTS.md`. They are not a substitute for the rows above.
