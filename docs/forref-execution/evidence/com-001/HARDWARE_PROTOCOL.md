# COM-001 Bip 6 protocol

State: **PREPARE VISUAL ONLY. LOCK NOT TESTED**. On `1.0.26` the founder reported the phone status `listening`, then CONFIG PREGĂTIT on the first Provision tap, then CONFIG PREGĂTIT again after Back → PROVISION → Provision. No console log was attached, so the installation UUID, request UUID, match id, and content hash were not compared. Those two rows are not certified. Unit tests do not certify the Bip 6. Do not mark Level 2 from this file.

App id `29566`, version `1.0.27` (code 27), boot `build=com-004-lock rev=f6efb1680837a4b2a09ac7c002c99ef9dc2300c4`. Install `dist/29566-FORREF-1.0.27-20261128095218.zab`. Do not install `1.0.20` or `1.0.21`. `app.bin` has no `createConnect` and no `GET_WATCH_PROVISION`. The PROVISION page bundle contains `createConnect`, `runHandshake`, `SUBMIT_WATCH_LOCK`, and `REPORT_WATCH_ACTIVATED`. The QR is in `TEST_RESULTS.md`. It expires 11:52 Europe/Bucharest on 5 December 2026. Open FORREF and stay on Home. A reboot on open fails the trial. Home → SETTINGS → PROVISION shows the UUID before any tap and logs `tx=evidence` without sending a request. Copy that line before tapping. It must name the same installation, request, match, and hash as the phone Inspect provision line, with `generation=1`, `canonical=accepted`, `readback=1`, `lock=0`, and `activation=0`. The phone root stays absent. Then tap Provision once, with the phone still listening. The tap keeps that request id and continues through lock and activation. One generation-1 root, then one activation record. A second root, a new request id, or a deleted match history fails the trial.

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
| BOOT | Install `1.0.27` and open FORREF from the app list. Leave it on Home for a few seconds. | Home shows OFFICIATE, TRAINING, and SETTINGS. The watch does not reboot. The boot log contains `FORREF_APP onCreate` and `build=com-004-lock`. | NOT TESTED |
| UUID | From Home, open SETTINGS, then PROVISION. Do not tap Provision yet. | Both UUID lines are visible. Joined, they are 36 characters. Back returns to Settings. The id matches the phone field. `tx=evidence` is present and no `tx=request` was logged on this open. | NOT TESTED |
| PING | `1.0.24` on the Bip 6. Repeated PING on one LINK visit. | Founder reported PONG. No console excerpt was attached. | FOUNDER REPORTED PASS |
| LINK-NAV | `1.0.24`. LINK → Back → LINK → PING. | Founder reported PONG. No console excerpt was attached. | FOUNDER REPORTED PASS |
| LINK-BT | `1.0.24`. Bluetooth off, then on, then PING. | Founder reported PONG. No console excerpt was attached. | FOUNDER REPORTED PASS |
| PREPARE-UI | `1.0.25`. Tap Provision with Bluetooth connected, with Bluetooth disabled, and after reconnect. | Founder reported `unavailable`, then `messaging`, then `unavailable`. A new phone match returned `listening`. An older prepared match returned `prepared-conflict`. No console excerpt was attached. | FOUNDER REPORTED |
| PREPARE | On `1.0.26`, with the phone listening for this UUID and one saved match, tap Provision. | The page showed CONFIG PREGĂTIT. The phone had already shown `listening`. No console excerpt was attached, so the request id, match id, and content hash were not compared. | FOUNDER REPORTED VISUAL |
| PREPARE-HOP | On `1.0.26`, if the page is not CONFIG PREPARED, copy the status and the `hop` line. | The status names one hop: `device:messaging` when Bluetooth is off, `fetch:timeout`, `fetch:connection-refused`, `fetch:permission`, `fetch:transport`, `bridge:` plus the phone reason, or `normalize:malformed`. The log has `elapsed` on `tx=fetch` and does not contain the canonical document. | NOT TESTED |
| PREPARE-CONFLICT | On the phone, open a match that already shows `prepared-conflict`. Tap Inspect provision, then Cancel prepared, then Prepare and listen. | Inspect names the changed field among `content-hash`, `writer-device`, and `principal`. Cancel returns `cancelled` only for `CONFIG_PREPARED` with the stored hash, no generation-1 root, and no sporting record. The same match then returns `listening`. A root or a sporting record stays in place. | NOT TESTED |
| PREPARE-NAV | On `1.0.26`, Back → PROVISION → Provision. | The page showed CONFIG PREGĂTIT again. No console excerpt was attached, so this is not proof that the request id and content hash stayed the same. | FOUNDER REPORTED VISUAL |
| EVIDENCE | On `1.0.27`, open PROVISION and do not tap. On the phone, tap Inspect provision for the same match. | `tx=evidence` names the same installation, request, match, and hash as the phone line, `generation=1`, `canonical=accepted`, `readback=1`, `lock=0`, `activation=0`. Phone `root=absent`. Neither line contains the canonical document. No new match was created. | NOT TESTED |
| LOCK | After EVIDENCE, with the phone still listening, tap Provision once. | `SUBMIT_WATCH_LOCK_V1` uses the evidence request id, match id, and content hash. `disposition=locked` and `durable` true. Exactly one generation-1 root, device id equal to the watch installation. The page then shows WATCH ACTIVATED only after that durable lock. | NOT TESTED |
| REPORT | Stay on the page until the activation report returns. | `REPORT_WATCH_ACTIVATED_V1` with the same request id. `disposition=recorded`. Phone phase `recorded`. Still one root. `saved` and `d1Certified` stay false. Match history is unchanged. | NOT TESTED |
| LOST-LOCK | After PREPARE, turn Bluetooth off before the lock response is visible, then turn it back on and open the provision page again. | The retry uses the same request id. One root. No second `phase` that goes backwards. | NOT TESTED |
| LOST-REPORT | After the watch shows activated, turn Bluetooth off before `recorded`, then reconnect and open the page again. | Watch stays activated. The retry reports `recorded` with the same request id. One root. | NOT TESTED |
| SIDE | After PREPARE, force-stop the Zepp app side and open the provision page again. | Same request id. No second root. The page does not show a prepared document for a different match. | NOT TESTED |
| BRIDGE | After LOCK, stop and start the Flutter debug process, then repeat the lock from the watch. | The phone correlation file still has the same request id. A `readBack` failure is `receipt-invalid` and `durable` false. A valid retry is `idempotent-lock` and does not insert a second root. | NOT TESTED |
| REPEAT | Send the same pending, lock, and activation again without changing the match. | Dispositions stay prepared, locked, and recorded. Request id unchanged. One root. | NOT TESTED |
| LIVE | Kick off. Turn Bluetooth off for 30 s during the half. | The clock and local goal path continue. No provision request is required to keep the half running. | NOT TESTED |

HTTP 409, HTTP 500, malformed JSON, and a contradictory body are covered by the software rows in `TEST_RESULTS.md`. They are not a substitute for the rows above.
