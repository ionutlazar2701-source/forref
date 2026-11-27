# COM-001 software results

State: **SOFTWARE PASS / HARDWARE GATE PENDING**. Not a Level 2 pass. The phone was not installed from this environment, and the QR was not scanned here.

Debug readiness: functional commit `870dab0e2f72532c7ee16f79464c473d443ce4d9`. Boot stamp `85ff4c0`. Boot name `com-001-debug-ready`. App `29566`, version `1.0.20` (code 20). `npm test`: 258 pass, 0 fail. `flutter test test/watch_provision_debug_settings_test.dart test/watch_provision_debug_bridge_test.dart`: 10 pass, 0 fail.

Settings keeps `WatchProvisionDebugSection` behind `kDebugMode`, and the bridge refuses unless `kDebugMode` is true. The release manifest has no `INTERNET` permission. A debug widget test opens Settings and finds Watch provision, Watch installation UUID, No saved match selected, and Prepare and listen, then selects a saved match. The listening status line is `listening` plus the content hash, written after `bridge.start`. The bridge test posts the pending body to that server and receives `disposition=prepared`.

The device app opens through ZML `BaseApp`, which assigns `globalData.messaging` before the clock boot. If that init throws, the clock still boots and the log is `FORREF_PROVISION messaging=absent`. The provision page reads messaging from `_options.globalData` or `globalData` and still paints the UUID before the handshake. A node test sends the page request through `dispatchSideRequest` to a loopback HTTP server and finishes `transport=recorded` with the fixture content hash. That server stands in for the phone. It is not a Bip 6 result.

This environment has no Android SDK (`flutter doctor` reports the toolchain missing). The installable debug session is `flutter run -d RZCY11BDMTX` from `apps/referee_phone` on the Windows machine that already sees SM A166B. That command keeps the existing debug signature and the application support files. Steps are in `HARDWARE_PROTOCOL.md`.

Identity hotfix: functional commit `7d8a8fc623307ef7f0d26f141ca9ffa34ec14fe3`. Boot name `com-001-ui-hotfix`. App `29566`, version `1.0.19` (code 19). `npm test` at that commit: 254 pass, 0 fail.

ZML 0.0.38 `BasePage` runs `globalData.messaging.onCall()` inside `onInit`, before the page `build`. The device app globalData is `{ demo: true }` and has no messaging object, so that call throws and the provision screen stays blank. The page is now a plain `Page`. It paints the stored UUID, or `INSTALLATION UNAVAILABLE`, before any handshake. A valid installation file is not rewritten. `1.0.18` reached the route and left this screen blank.

Navigation build: functional commit `3a2f577e90b5bfe06e31851d5a6d8bccdfd2f25c`. Boot stamp `b7c498d`. Boot name `com-001-ui`. App `29566`, version `1.0.18` (code 18). Home keeps OFFICIATE and TRAINING and adds SETTINGS.

Transport functional commit `9b662fbf1c4ee4f75ce01d05b215c1ac589cae34`. Boot stamp commit `f03e1d9d738d1abd9e6c9c989844d0c741df8d41`. Boot name `com-001`.

Baseline: PR #84, commit `e89c2b2041679b9bfaa5132afd903a9e3b921920`. Clock cadence, Goal journal, score, and authority-writer rules are unchanged.

## Receipt rule

`decidePhoneAuthorityLock` still returns early for `authorityConflict`, `recoveryRequired`, and `configInvalid`. It no longer returns early for an existing `phoneAuthorityLocked` root.

A missing receipt, or transport down, stays `configPrepared` with reason `transport-unavailable` and `rootToCommit` null. A present receipt that is not a generation-1 readback stays `configPrepared` with reason `receipt-invalid`. A receipt whose hash or writer disagrees with the document is `authorityConflict` with reason `receipt-mismatch`. The stored root is not deleted and is not inserted again.

`durable` on the debug bridge is true only when that decision state is `phoneAuthorityLocked`. That state is reached for a new lock, or for `idempotent-lock`, only after the receipt in this call is usable. An existing root does not make `readBack: false` durable.

## ZML timeout

`@zeppos/zml` 0.0.38 `dist/zml-side.js` implements Side Service fetch as global `fetch`. The options object is `{timeout:1e4, ...request}`. The Fetch call does not abort on that field, so `timeout: 4000` on `this.fetch` is not a deadline.

The page-to-side `request()` path does abort. Its default is `timeout:6e4`, and a timer rejects with `request id=… timeout in ${t.timeout}ms`. The provision page passes `{ timeout: 8000 }`. The side service wraps `this.fetch` in `fetchWithDeadline` at 4000 ms and does not pass `timeout: 4000` into fetch.

## Correlation

Watch file `forref_watch_provision_correlation_v1.txt`. Phone debug file `forref_watch_provision_correlation_v1.json` under the application support directory. Both keep installation UUID, request UUID, generation 1, match id, and content hash. A retry reuses that request id. A second handshake for the same installation returns `busy` until the first returns. A later phase does not rewrite an earlier phase backwards.

Logs are `FORREF_PROVISION` lines with `tx=request`, `tx=response`, `tx=transition`, or `tx=recover`, plus installation, request, match, hash, generation, http, disposition, and reason. The canonical document and team names are not on those lines.

## Fault injection

| Interruption | Final phone root | Watch admission | Correlation |
| --- | --- | --- | --- |
| Lock response lost after the watch stored the verified document | No root until a later usable receipt | `WATCH_CONFIG_VERIFIED` | Same request id, phase `verified` |
| Phone SQLite lock committed, then the process restarts, then `readBack: false` | One root, same device id | n/a | Same request id, phase stays `locked`, response `receipt-invalid`, `durable` false |
| Same restart, then the original request with `readBack: true` | Same one root, `idempotent-lock`, no second insert | n/a | Same request id |
| A different request id after that lock | Same one root | n/a | Refused `correlation` |
| Activation report lost | Root already locked | `WATCH_ACTIVATED` | Phase `activated`, then a retry reaches `reported` on `recorded` |
| Prepared body for another match after the hash is bound | Unchanged | Unchanged | Refused `binding` |
| Second handshake while the first request is open | n/a | Unchanged | `busy`, one request id |
| HTTP 409, HTTP 500, malformed JSON, contradictory `prepared`/`locked` | No new root | No canonical stored | Request id kept, disposition not a success |
| Lock before any pending | No root | n/a | Refused `order` |

## Suite

`npm test` in `apps/forref_watch_zepp`: 258 pass, 0 fail.

`flutter test test/watch_provision_debug_settings_test.dart test/watch_provision_debug_bridge_test.dart` in `apps/referee_phone`: 10 pass, 0 fail.

`./tool/verify_cloud.sh`: PASSED.

## Diagnostic package

Install `1.0.20`. Home → SETTINGS → PROVISION shows the installation UUID without a phone connection. The app boot log must include `FORREF_PROVISION messaging=ready` before a provision request. The first console line on that page is `FORREF_PROVISION page=build`, then `device width=` `height=` `layout=` and `installation=` with the 36-character id. A storage failure logs `tx=recover` and draws `INSTALLATION UNAVAILABLE`.

Zeus CLI 1.10.3, target Amazfit Bip 6, device sources `9765120`, `9765121`, `10158337`. App id `29566`, version `1.0.20` (code 20), boot `build=com-001-debug-ready rev=870dab0e2f72532c7ee16f79464c473d443ce4d9`. The preview package is `dist/29566-FORREF-1.0.20-20261127215753.zab` (368988 bytes, sha256 `5b0d9a44f47dc500883931b6644ada18fbdc1e9d4dff4631e26bdb3f868554bf`). It is not committed. The QR expires `2026-12-04 21:57:55` on the machine clock (UTC), which is 23:57 Europe/Bucharest. The QR was not scanned here.

`1.0.19` (`dist/29566-FORREF-1.0.19-20261127101748.zab`, sha256 `84a4589771e69967cdc75a376d197434521c3a0e7cdbb1e7f008dc952ae02482`) paints the UUID and does not initialize `globalData.messaging`.

`1.0.18` (`dist/29566-FORREF-1.0.18-20261127100800.zab`, sha256 `38bae40d41a92d9c6aa426810adbc2406b263e69ae28ab604e13d9cf84108583`) is the build that opened a blank provision page. The `1.0.17` package is the earlier transport build.

```
[FORREF - 1.0.20]
Supported device: Amazfit Bip 6
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
█ ▄▄▄▄▄ █ ▀▀▄  ▀█▀ ▄▄█▄▄█▀▄▀█▀█ ▄▄▄▄▄ █
█ █   █ ███ ▄▄  ▄▄▄▀▄  ▀ ▄ ▀█▄█ █   █ █
█ █▄▄▄█ █ ▄▄ █ ▄▄▀▄██▀█ ██ ██▀█ █▄▄▄█ █
█▄▄▄▄▄▄▄█ █ ▀ █▄█▄█ ▀▄█▄█ █ ▀ █▄▄▄▄▄▄▄█
█ ▄ ▀▀▄▄▀   ██ ▀▀▀ █▀ ▀▄  █▀▀▄▄  ▄█▀  █
█▀▀ ▄█ ▄▀█▀▀▄█▄  ██▄▄▀█▀▄▀▄█▄▀█▄▀ ▄█ ▄█
█▄ ▀▄ █▄ ▄  ▄ ██▀  █  ██▀▄▀█▀ █ ▄█ ▀  █
█ █▀   ▄ ▀██▀ ██ ▀▄▀ ▄▄█▄▄█▀ ▀▀▄ ▄██▄▄█
█▀ ▄ ▄▀▄▄█▀▀███▀█ ▄▀▀ ▀█ ▀▀█▀   ▀█ ▀█ █
█ ██▀▀▄▄▄▄▀▄▄██  ▄▄█  █▀▄▄▄▀ █▄ █ ▀█▀ █
█▄▀▀▄█ ▄▀  ▀▄ ▀▀█▀▀█▄ █▀ ▀▀▄  ▄  █▄█▄▀█
█▄ ▀ █▄▄▀██▀▀ ▄  ▄█▀ ▀█▀▄██▀  █▀ █▀▄█▄█
██▀▀ ▀█▄█▀▄▄██▀█▀▀▄█ ▀▀█  █▀▀▄▀  ███  █
█▄▄▄▄▀█▄█ ██▄██▀▄▄██ ▀██ ▀▄█▄▄▄▀█  ▄█ █
█▄▄██▄█▄▄ ██▄  ██ ▀█▀▄▀█▀▄▀█  ▄▄▄ ▄▀ ▀█
█ ▄▄▄▄▄ █▀█ ▀ ▄▄▄██▄▄ ▄█ ██▀▀ █▄█ █▄█ █
█ █   █ ██ ▀██ ▄█▀▄█  ▀█ ▀▀█▄▄ ▄▄  ▀▀██
█ █▄▄▄█ █ ▄▄▄█▀█▄██ ▄██▀▄ █▀   █▀▄▀▄█▄█
█▄▄▄▄▄▄▄█▄▄▄▄▄▄██▄██▄▄███▄███▄█▄██▄██▄█
```
