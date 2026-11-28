# COM-001 Bip 6 protocol

## Send to Watch

State: **1.0.35 SOFTWARE PASS. HARDWARE GATE PENDING. NOT ACTIVATED**. Watch source is `1.0.35` (`watch-config-035`, rev `a8db8e206942861ef3e2c2a6b889b754ac052e0e`). The paired watch receives one saved match. The phone shows Configuration Verified only after the watch reads the configuration back. Lock and activation stay disabled. No authority root is created. This section does not certify the Bip 6.

Do not uninstall either app. Do not type an installation UUID. Do not tap Provision, Enroll, Prepare, Listen, or Cancel. Do not delete a correlation file.

1. Install the MCT watch package in place. Force-stop Zepp, open Zepp, and stay on Home.
2. On the phone, from this branch, run `flutter run -d RZCY11BDMTX`. Open Settings. If the watch is not already paired, tap **Connect Watch**, then on the watch tap **CONFIRM**. The phone shows Connected & Verified.
3. Choose a saved match that has not been kicked off. Tap **Send to Watch**. The phone says it is waiting for the watch.
4. On the watch, open SETTINGS, then PROVISION. Tap **RECEIVE** once.
5. The phone shows **Configuration Verified**, the two team names, the half length, and **Not activated**. The watch shows the same two names, `45 + 45` when the halves are 45 minutes, and **Verified · not activated**. Tap **RECEIVE** again. The phone says the match was already saved.

| Screen | Meaning |
| --- | --- |
| Configuration Verified | The watch stored this match and read it back. Authority is not activated. |
| Configuration Verified, already saved | The same watch repeated the transfer. The stored configuration was not written again. |
| Waiting for the watch | The phone is holding the match until the watch verifies it. |
| Pair the watch before sending a match | Connect Watch has not stored a witness. |
| This match is a pairing record | The selected match is the pairing fixture. Choose another saved match. |
| This match has already started | Kick-off has happened. The configuration was not sent. |
| The stored match configuration was kept | The saved document does not match the stored one. Nothing was replaced. |
| Stored watch was kept | A different installation arrived. The writer was not replaced. |
| Phone unreachable, on the watch | The side service could not reach the phone after three tries. Tap Send to Watch and RECEIVE again. |

## Connect Watch

State: **1.0.34 SOFTWARE PASS. HARDWARE GATE PENDING. LOCK DISABLED**. Watch source is `1.0.34` (`watch-pair-034`, rev `121d2bfea53ce325cea2cc0e69d59f806c828c0b`). Package `dist/29566-FORREF-1.0.34-20261128172845.zab`, sha256 `ecce27ca297465041b0f8923b6988d5bd34e7f8a031eeb8df2667326e1e3133b`. The QR is in `TEST_RESULTS.md` and expires 19:28 Europe/Bucharest on 5 December 2026. Rows H1–H11 and E1–E8 stay **LOCAL GATE REQUIRED**. This file does not certify the Bip 6.

Do not uninstall FORREF Watch, the Zepp app, or FORREF Mobile. Do not reset a match, clear storage, cancel a prepared provision, or delete a correlation file. Do not type an installation UUID. Do not tap Prepare and listen, Listen, Enroll witness, or Cancel prepared. Do not tap Provision on the watch.

## Connect Watch

The Zepp Side Service runs inside the Zepp app on the phone and fetches `http://127.0.0.1:47221/watch-provision/v1`. That is the supported path in this repository. The watch does not open the phone's loopback by itself, and this flow does not add a cloud call.

`bridge:installation` was the phone refusing a request whose installation id was not the stored writer. That writer had been taken from the UUID typed on the phone before the watch spoke. `fetch:transport` is the side-service fetch failing with an error that is not a timeout, a permission failure, or a refused connection. The listener existed only after a manual Settings action.

Connect Watch listens before a writer exists. The first valid watch request stores that watch as the writer of a new pairing match and shows **Connected & Verified** on the phone. The watch shows the same words. A second confirm stays verified. A different watch is refused. The phone shows the stored preview and the request preview, and the stored writer stays. The historical match and its correlation file are not written. A dead phone is retried three times. The watch then shows **Phone unreachable**.

The listener is in the debug phone build. The release manifest still has no `INTERNET` permission. A match in progress does not use this port.

1. Install the pairing watch package in place. Force-stop Zepp from Android Settings, then open Zepp. Open FORREF and stay on Home. A reboot on open fails the trial.
2. On the phone, from this branch, run `flutter run -d RZCY11BDMTX` without uninstalling. Open Settings. Tap **Connect Watch**. The screen says it is waiting for the watch.
3. On the watch, open SETTINGS, then PROVISION. Tap **CONFIRM** once.
4. The phone shows **Connected & Verified** and a short watch preview. The watch shows **Connected & Verified**. Tap **CONFIRM** again. The phone stays **Connected & Verified** and says the watch was already paired.
5. If the phone says the stored watch was kept, stop. That screen names both previews. Do not type a UUID over the stored writer.

| Result on the phone | What it means |
| --- | --- |
| Connected & Verified | The watch installation was stored for this pairing match. The previous match was not changed. |
| Connected & Verified, already paired | The same watch repeated the request. One witness remains. |
| Stored watch … was kept | A different installation arrived. The stored writer was not replaced. |
| Pairing stopped | The phone refused the request. The reason is on that line. The stored writer was not changed. |
| Phone unreachable, on the watch | The side service could not reach the phone listener after three tries. Tap Connect Watch and confirm again. |

## 1.0.33 enrollment trial

The historical watch file `forref_watch_provision_correlation_v1.txt` and the phone file `forref_watch_provision_correlation_v1.json` keep the previous request. A second match on those files is the same session. This trial uses other files: `forref_watch_enroll_correlation_v1.txt`, `forref_watch_enroll_v1.root`, `forref_watch_enroll_v1.admission`, and `forref_watch_enroll_correlation_v1.json`. The historical Provision button is unchanged.

Install `1.0.33` in place. Force-stop Zepp from Android Settings, then open Zepp again. Open FORREF and stay on Home. A reboot on open fails the trial. On the phone debug build, from this branch, run `flutter run -d RZCY11BDMTX` without uninstalling. Open Settings. Type the installation UUID from the current watch `FORREF_IDENTITY` line. Do not select the saved match. Tap **Enroll witness**. Copy the `FORREF_ENROLL tx=open` line. `status=listening` and `same=1` are required. The `match=` value after `status` is a new match. `writer=` is the previously stored writer. `root=0`. Any other status stops the trial. Do not Cancel prepared.

From the phone browser open `http://127.0.0.1:47221/`. The body is `disposition=listening`, `writes=0`, and the new match id. That browser line is not a Zepp POST.

On the watch, open SETTINGS, then PROVISION. Do not tap PROVISION. Tap ENROLL once. Copy `FORREF_ENROLL tx=preflight`, `historical-same=1`, `FORREF_WITNESS`, and the phone `tx=identity` line. The witness line for this watch is expected to stay `class=hex32`, `v=2`, preview `c533...058d`. The phone line for the first tap is `reason=observed`. Tap ENROLL again. The phone line is `reason=replay`. On the phone tap **Read enroll**. `witnesses=1`, `eligible=1`, and the historical `fp=` matches the open line. `root=0`. Do not Cancel prepared.

A conflicting digest version and a different installation are covered by `watch_enroll_session_test.dart`. They return `replay-conflict` and `recovery-required` without a second eligible witness and without changing the historical stage. This build does not offer a watch control that sends a forged digest. Do not treat that automated result as a Bip 6 pass.

## Writer comparison, read only

The 1.0.33 phone log `tx=identity reason=installation` is printed by `_classifyOther`. That branch runs only when the SQLite column `writer_device_id` for the listener match is not the request `installationId`. The comparison is the raw string. `_observeWitness` is not called, so no `watch_witness_observed` row is stored. Settings Inspect does not read the watch body. It compares the installation typed in the text field with the stage of the match selected in the picker. `changed=none` means that text field matches the stored writer of the selected match. The identity line prints the request installation, not the stored writer. Those two screens can both look right while the request and the column differ.

This phone patch does not move the writer, cancel the stage, delete a correlation, or change the watch package. Watch `1.0.33` stays installed. Rerun the phone debug build from this branch with `flutter run -d RZCY11BDMTX`. Do not uninstall either app. Do not tap Cancel prepared. Do not tap Provision on the watch. Do not tap Prepare and listen. Leave the installation field as `0f864ebe-0b89-404d-af72-a98f34ce4e5e`.

Tap **Enroll witness** once. Continue only when the open line is `status=listening` or `status=reused` and `match=e932fd5d-20c9-4f3a-8b6b-1ba5032bc81a`. `enroll-writer`, `enroll-ambiguous`, `enroll-installation`, or any other match id stops the trial. Copy that line and do not type a different UUID. Chrome GET `http://127.0.0.1:47221/` must show that same match and `writes=0`. On the watch open SETTINGS, then PROVISION, and tap ENROLL once.

Copy the full phone line `FORREF_PROVISION tx=writer-compare`. Then tap Inspect for that same match and copy that line too.

| Field | How to read it |
| --- | --- |
| `equal` | `1` means the request UUID and the SQLite writer were the same string. `0` means they were not. |
| `mismatch-at` | Zero-based index of the first code unit that differs. `none` when `equal=1`. |
| `mismatch-request-unit` and `mismatch-stored-unit` | Those code units in hexadecimal. `end` means that string is shorter. |
| `branch` | `other-installation` is `_classifyOther`. `current-writer` continues toward the witness. |
| `observe` | `0` means `_observeWitness` was not called. `1` means it was called. |
| `inspect-changed` | Inspect of this same store and `stage-match`, using the request UUID as the requested writer. `writer-device` means the request is not the stored writer. `none` means it is. |
| Settings `changed=none` | The text field, not the watch body. It can be `none` while `inspect-changed=writer-device`. |
| `column-canonical` | `0` means the writer inside the stored canonical text differs from the column. The patch records that. It does not rewrite either value. |

Do not Cancel prepared after reading the line. Do not type a UUID over the stored writer. Do not tap Provision. This procedure does not certify enrollment. E1–E8 stay **LOCAL GATE REQUIRED**.

| Gate | What to record | Pass is not available until the founder attaches the log |
| --- | --- | --- |
| E1 | `FORREF_ENROLL tx=open` before the watch tap. | `status=listening`, `same=1`, a new match id, the old writer, `root=0`. |
| E2 | Chrome GET `http://127.0.0.1:47221/`. | `disposition=listening`, `writes=0`, and the new match id. |
| E3 | One ENROLL tap. `FORREF_WITNESS` and `historical-same`. | `class=hex32` or `bytes32`, `v=2`, preview `c533...058d`, `historical-same=1`. |
| E4 | Phone `tx=identity` for that tap. | `reason=observed` for the new match and the current installation. |
| E5 | The same ENROLL tap again. | `reason=replay`. Read enroll shows `witnesses=1` and `eligible=1`. |
| E6 | Read enroll compared with the open line. | The same historical `fp`, writer, stage, `root=0`, and `records=count=0`. |
| E7 | The old match is not cancelled and its UUID is not replaced. | No Cancel prepared. The stored writer is the one recorded before the trial. |
| E8 | Conflicting version and conflicting installation. | Software rows in `TEST_RESULTS.md`. Not a hardware pass. |

## 1.0.32 byte-string trial

The 1.0.33 enrollment trial above is the current procedure. Do not tap Provision for that trial. This section records the 1.0.32 package.

State: **1.0.32 BUILT. HARDWARE GATE PENDING. LOCK DISABLED**. Watch source is `1.0.32` (`identity-bytes32-032`, rev `12dfb9d197cbea419129f533ad865fbd613a71d6`). Package `dist/29566-FORREF-1.0.32-20261128142742.zab`, sha256 `b78584bdcf9175a5391f165c32fb8eee0191a7f63301dfc79a32054f7d89c922`. The QR is in `TEST_RESULTS.md` and expires 16:27 Europe/Bucharest on 5 December 2026. `1.0.31` was run on the Amazfit Bip 6. The witness line was `kind=absent class=unsupported-or-invalid len=32`. `FORREF_IDENTITY` was `case=fresh created=1`. `1.0.30` was uninstalled before `1.0.31`, so that fresh installation is not an in-place upgrade result. The software gate had required 64 hex characters. The Zepp OS 4.2 contract and this log both describe a 32-byte string. `1.0.32` accepts that shape as digest version 2. It does not reinterpret a version-1 digest. Rows H1–H11 stay **LOCAL GATE REQUIRED**. This file does not certify the Bip 6.

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
