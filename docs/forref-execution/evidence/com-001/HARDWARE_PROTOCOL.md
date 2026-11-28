# COM-001 Bip 6 protocol

State: **1.0.32 BUILT. HARDWARE GATE PENDING. LOCK DISABLED**. `1.0.31` was run on the Amazfit Bip 6. The witness line was `kind=absent class=unsupported-or-invalid len=32`. `FORREF_IDENTITY` was `case=fresh created=1`. `1.0.30` was uninstalled before `1.0.31`, so that fresh installation is not an in-place upgrade result. The software gate had required 64 hex characters. The Zepp OS 4.2 contract and this log both describe a 32-byte string. `1.0.32` accepts that shape as digest version 2. It does not reinterpret a version-1 digest. Rows H1–H11 stay **LOCAL GATE REQUIRED**. This file does not certify the Bip 6.

Do not uninstall FORREF Watch, the Zepp app, or FORREF Mobile. Do not reset the match, clear storage, or cancel a prepared provision. Do not type a new installation UUID over the stored writer. A fingerprint match does not create a witness that was never stored, and it does not clear `prepared-conflict`.

## 1.0.32 non-destructive trial

Install `1.0.32` in place. The version code is 32. Force-stop Zepp from Android Settings, then open Zepp again. Force-stop replaces the loaded Side Service. It does not clear watch files. Open FORREF and stay on Home. A reboot on open fails the trial.

From Home, open SETTINGS, then PROVISION. Do not tap Provision yet. Copy `FORREF_IDENTITY` and `FORREF_WITNESS`. Leave the app and open PROVISION again. Copy both lines. Restart the watch and copy both lines a third time.

`id` on `FORREF_IDENTITY` is the installation UUID. `preview` on `FORREF_WITNESS` is the platform fingerprint. Those are different facts. `case=reused` and `created=0` with the same `id` as the `1.0.31` line is installation continuity. The same `preview` across reopen and reboot is fingerprint continuity. `case=fresh` on this in-place install is a HOLD.

On the phone debug build, from this branch, run `flutter run -d RZCY11BDMTX` without uninstalling. Open Settings, select the saved match, and tap **Listen**. Listen does not prepare a match. If the line is `prepared-conflict`, leave it. Do not Cancel prepared. From the phone browser open `http://127.0.0.1:47221/`. The body is `disposition=listening` and `writes=0`. That browser line is not a Zepp POST. Then tap Provision once on the watch.

The witness line names `kind`, `class`, `len`, `utf8`, `hex`, `ascii`, `ctrl`, and, when a digest exists, `preview` and `v`. `preview` is four hex characters, three dots, and four hex characters. The line does not contain the platform id or the full digest. `hex=1` means the 32 bytes were ASCII hex. `hex=0` means they were not.

| Gate | What to record | Pass is not available until the founder attaches the log |
| --- | --- | --- |
| H1 | `FORREF_WITNESS` class, length, `hex`, and preview. | `class=hex32` or `class=bytes32`, `len=32`, `v=2`, and a preview. `non-byte32` or `unsupported-or-invalid` is a HOLD. |
| H2 | The same witness line after reopen and after a watch restart, plus `FORREF_IDENTITY` `id`. | The same preview. The same installation id, with `case=reused` and `created=0`. |
| H3 | In-place upgrade from the installed `1.0.31` to `1.0.32`. No uninstall. Pre and post installation id and preview. | A changed installation id is a HOLD. Do not adopt another id. |
| H4 | Not this trial. Do not uninstall. | A later destructive reinstall is out of scope until H1–H3 have logs. |
| H5 | Phone Listen, Chrome GET, then the Zepp POST. | GET `listening` and the Zepp `http` line are separate. `Error -2` remains a transport HOLD. |
| H6 | Pending from the current writer with a witness. | Phone log `reason=observed` and one `watch_witness_observed` row with `digest_version` 2. A stage that has no witness does not gain one from a different installation. |
| H7 | A later installation with the same preview, only when a witness row already exists. | `reason=recovery-required`. No `disposition=prepared`. Writer unchanged. If no witness was stored, the reason is `installation`, not `recovery-required`. |
| H8 | A different model, a wrong principal, or a different digest. | `installation`, `installation-conflict`, or `identity-evidence-unavailable`. No other match id in the response. |
| H9 | Repeat the same request id. | One event. The same reason. |
| H10 | A match that already has a generation-1 root. | The root device id is unchanged. The new installation does not lock or record. |
| H11 | Kick off on the already authorized watch and turn Bluetooth off for 30 seconds. | The clock continues. The phone link is not required. |

The phone sentence for H7 is the watch status `RECOVERY REQUIRED` / `RECUPERARE NECESARĂ`. That means a possible previously used watch. This installation cannot officiate that match. It is not an authenticated device and it is not a writer transfer.

State: **PREPARE NOT TESTED. LOCK DISABLED**. No Bip 6 `FORREF_IDENTITY` line and no `tx=probe` line were attached for `1.0.29`. Those rows stay **LOCAL GATE REQUIRED**. Across successive Bip 6 builds the displayed installation UUID changed: `166e7c3b-…-e43e`, `03e0d543-…-0a51`, `12a79650-…-f966`. FORREF Mobile kept the previous writer and returned `prepared-conflict`. The watch code minted a new random UUID whenever `forref_watch_installation_v1.txt` read as missing, and those files were written under a bare name. Zepp documents `data://` as the directory kept across an upgrade. This repository has no device log that shows those files were deleted. Do not treat the three UUIDs as proof that Zepp wiped storage. `1.0.28` side parity and the HTTP probe stay separate rows and are still not certified. Unit tests do not certify the Bip 6. Do not mark Level 2 from this file.

App id `29566`, version `1.0.30` (code 30), boot `build=com-004r-share rev=29dee454fa5ebba73442387275abf45decfb7499`. Install `dist/29566-FORREF-1.0.30-20261128123821.zab`. The previous package remains `dist/29566-FORREF-1.0.29-20261128115804.zab`. Do not install `1.0.20` or `1.0.21`. Do not uninstall the Zepp app, FORREF Mobile, or FORREF Watch. Do not clear the watch UUID, the correlation file, a prepared match, or an authority root. `app.bin` has no `createConnect` and no `GET_WATCH_PROVISION`. The PROVISION page bundle contains `data://`, `FORREF_IDENTITY`, `runPrepare`, and `GET_WATCH_PROVISION`. It does not contain `runHandshake`, `runSideDiagnostic`, or `SUBMIT_WATCH_LOCK`. `app-side.js` still refuses lock and activation with `prepare-only` before fetch. `app-side.js` contains `tx=side-build` and does not contain `tx=recover method=`. The QR is in `TEST_RESULTS.md`. It expires 14:38 Europe/Bucharest on 5 December 2026.

The Side Service runs in the Zepp phone app. A new preview updates the watch app when the version code increases and delivers a new side bundle to the phone. A Side Service that is already running keeps its loaded JavaScript until the Zepp process is destroyed. After installing `1.0.30`, force-stop Zepp from Android Settings, then open Zepp again. Force-stop replaces the loaded Side Service. It does not clear watch files. Open FORREF and stay on Home. A reboot on open fails the trial. Home → SETTINGS → PROVISION logs `FORREF_IDENTITY` before any tap. Copy that line. `case=reused` with `created=0` and the UUID already on the watch is continuity. `reason=lost-identity-prepared`, `lost-identity-activated`, or `lost-identity-state` means a previous file is still present and this build refused to mint a writer. Do not tap Provision on that screen. The tap sends nothing when the identity is not intact. When the identity is intact, enter that same UUID on the phone, choose the saved match, and tap Prepare and listen. The phone line must begin with `listening`. A `prepared-conflict` with `changed=writer-device` stops the trial. Do not Cancel prepared. Then tap Provision once. The watch sends `GET_WATCH_PROVISION_V1`. The side posts `operation=pending`. Copy `outcome=PREPARED` and compare `installation`, `request`, `match`, and `hash` with the phone `listening` line. `canonical=accepted` is the pass. The log must not contain the canonical document or the team names. The phone must show no new authority root. The log has no `SUBMIT_WATCH_LOCK_V1` and no `REPORT_WATCH_ACTIVATED_V1`. A transport failure stays on its hop. Do not reset the installation id to obtain a pass. Lock and activation are refused before fetch on this build.

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

On the matches screen, open Settings. The page shows Watch provision, the field Watch installation UUID, No saved match selected, Prepare and listen, Inspect provision, and Cancel prepared. Enter the 36-character watch UUID, choose one saved match whose home and away names are filled in, then tap Prepare and listen. The status line begins with `listening` and the content hash. If it is `prepared-conflict` because `changed=writer-device`, leave the row. Do not Cancel prepared, and do not type a different UUID into the phone, to make this watch match a stored writer. Inspect provision names `changed=content-hash`, `writer-device`, `principal`, or `none`, plus `root=` and `records=`, and the stored hash, writer, and principal. It does not include the canonical document. Cancel prepared removes a `CONFIG_PREPARED` row through `cancelPreparedWatchMatch`, using the stored hash, and is not the identity recovery for this build. Cancellation is refused when the stage is not `CONFIG_PREPARED`, the hash does not match, a generation-1 root exists, or a sporting record exists. Those refusals leave the root and the match history in place. After `cancelled`, tap Prepare and listen again. The bridge is `127.0.0.1:47221/watch-provision/v1` on that phone. The Zepp app must be on the same phone. Leave the `flutter run` terminal open.

This is the Android-local debug route only: Flutter debug bridge on `127.0.0.1:47221`, path `/watch-provision/v1`, then the Zepp Side Service, then the watch page. It is not a production transport. An active match must not need this link. Goal capture stays on the watch. This protocol does not enable Goal-to-phone replication.

## What to copy

From the watch console, copy the `FORREF_IDENTITY` line before any tap. It names `case`, `created`, `reason`, `evidence`, file presence, `phase`, and `id`. Then copy the `FORREF_PROVISION` lines for the trial. Each line is one of `tx=request`, `tx=side`, `tx=fetch`, `tx=bridge`, `tx=normalize`, `tx=response`, `tx=transition`, `tx=recover`. Keep `hop`, `category`, `elapsed`, `installation`, `request`, `match`, `hash`, `generation`, `http`, `disposition`, and `reason`.

Do not paste the canonical document or the team names. After the trial, record three facts in the Result column:

- Phone root: absent, or the one device id.
- Watch admission: the state named by the page or the last `tx=transition`.
- Correlation: the request id, and whether a retry used that same id.

A line with `disposition=prepared`, `locked`, or `recorded` while `http` is not 200, or while `durable` is true on a prepared or recorded body, fails the trial. A second authority root fails the trial. A new request id on a retry of the same watch and match fails the trial.

## Trial matrix

| Test | Steps | Pass | Result |
| --- | --- | --- | --- |
| BOOT | Install `1.0.30` without uninstalling FORREF Watch. Open FORREF from the app list. Leave it on Home for a few seconds. | Home shows OFFICIATE, TRAINING, and SETTINGS. The watch does not reboot. The boot log contains `FORREF_APP onCreate` and `build=com-004r-share`. | NOT TESTED |
| IDENTITY | From Home, open SETTINGS, then PROVISION. Do not tap Provision yet. Copy `FORREF_IDENTITY`. | `case=reused`, `created=0`, and `id` is the UUID already on this watch, with `evidence=data` or `evidence=legacy`. A second open and a reboot show the same `id`. If prepared or authority files remain and the UUID file does not, `case=recovery` and the reason is `lost-identity-prepared`, `lost-identity-activated`, or `lost-identity-state`, and no new UUID is painted. `case=fresh` appears only when the log shows every probed file absent. No sporting journal or authority root was deleted. No `1.0.29` line was attached before this package. | LOCAL GATE REQUIRED |
| SHARE | On `1.0.30`, with `case=reused` and the phone `listening` for that UUID and one saved match, tap Provision once. | `outcome=PREPARED` names the same `installation`, `request`, `match`, and `hash` as the phone `listening` line, with `canonical=accepted` and `generation=1`. The phone has no new authority root. The log has no `SUBMIT_WATCH_LOCK_V1` and no `REPORT_WATCH_ACTIVATED_V1`. The canonical document and the team names are not in the log. | LOCAL GATE REQUIRED |
| IDENTITY-NEXT | Install the next versioned build after `1.0.29` in place, then open PROVISION. | `case=reused`, `created=0`, and the same `id` as the `1.0.29` `FORREF_IDENTITY` line. That pair is the hardware proof that `data://` survived an upgrade. | NOT THIS BUILD |
| UUID | From Home, open SETTINGS, then PROVISION. Do not tap Provision yet. | Both UUID lines are visible when identity is intact. Joined, they are 36 characters. Back returns to Settings. `tx=device-build` names `version=1.0.29` and `code=29`. No `tx=probe` was logged on this open. | NOT TESTED |
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
| LOCK | This `1.0.30` tap. | The log has no `SUBMIT_WATCH_LOCK_V1` and no `REPORT_WATCH_ACTIVATED_V1`. A lock or activation method is refused `prepare-only` before fetch. Authority is not committed. The successful lock trial waits until the SHARE row is certified on hardware. | NOT TESTED |
| REPORT | This `1.0.30` tap. | No activation report is sent. Phone phase is unchanged. `saved` and `d1Certified` stay false. Match history is unchanged. | NOT TESTED |
| LOST-LOCK | After a later build enables lock, turn Bluetooth off before the lock response is visible, then turn it back on and open the provision page again. | The retry uses the same request id. One root. No second `phase` that goes backwards. | NOT THIS BUILD |
| LOST-REPORT | After the watch shows activated on that later build, turn Bluetooth off before `recorded`, then reconnect and open the page again. | Watch stays activated. The retry reports `recorded` with the same request id. One root. | NOT THIS BUILD |
| SIDE | After prepare on that later build, force-stop the Zepp app and open the provision page again. | Same request id. No second root. The page does not show a prepared document for a different match. | NOT THIS BUILD |
| BRIDGE | After lock on that later build, stop and start the Flutter debug process, then repeat the lock from the watch. | The phone correlation file still has the same request id. A `readBack` failure is `receipt-invalid` and `durable` false. A valid retry is `idempotent-lock` and does not insert a second root. | NOT THIS BUILD |
| REPEAT | Send the same pending, lock, and activation again without changing the match. | Dispositions stay prepared, locked, and recorded. Request id unchanged. One root. | NOT THIS BUILD |
| LIVE | Kick off. Turn Bluetooth off for 30 s during the half. | The clock and local goal path continue. No provision request is required to keep the half running. | NOT TESTED |

HTTP 409, HTTP 500, malformed JSON, and a contradictory body are covered by the software rows in `TEST_RESULTS.md`. They are not a substitute for the rows above.
