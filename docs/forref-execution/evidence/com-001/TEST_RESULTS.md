# COM-001 software results

State: **SOFTWARE PASS / HARDWARE GATE PENDING**. Not a Level 2 pass. The QR was not scanned here.

Functional commit `9b662fbf1c4ee4f75ce01d05b215c1ac589cae34`. Boot stamp commit `f03e1d9d738d1abd9e6c9c989844d0c741df8d41`. Boot name `com-001`.

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

`npm test` in `apps/forref_watch_zepp`: 247 pass, 0 fail.

`dart test test/watch_provision_v1_test.dart` in `packages/forref_match_core`: 23 pass.

`flutter test test/watch_provision_debug_bridge_test.dart test/watch_provision_a1_test.dart` in `apps/referee_phone`: 13 pass.

`./tool/verify_cloud.sh`: PASSED.

## Diagnostic package

Zeus CLI 1.10.3, target Amazfit Bip 6, device sources `9765120`, `9765121`, `10158337`. App id `29566`, version `1.0.17` (code 17). The preview package is `dist/29566-FORREF-1.0.17-20261127093720.zab` (366033 bytes, sha256 `b70389d8def307bd27e3d66c077896c45906a24c0c143bd7b745c404119c4b1a`). It is not committed. The QR expires `2026-12-04 09:37:23` on the machine clock (UTC), which is 11:37 Europe/Bucharest. The QR was not scanned here.

```
[FORREF - 1.0.17]
Supported device: Amazfit Bip 6
▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
█ ▄▄▄▄▄ █ ▀▀▄  █▄██▄█▀▄▄█▀▄▀█▀█ ▄▄▄▄▄ █
█ █   █ ███ ▄▄▄ ▀█   █ ▀ ▄ ▀█▄█ █   █ █
█ █▄▄▄█ █ ▄▄ █▀▄█▀▀█▄██ ██ ██▀█ █▄▄▄█ █
█▄▄▄▄▄▄▄█ █ ▀ █ ▀ █▄▀▄█▄█ █ ▀ █▄▄▄▄▄▄▄█
█▄▄▄██▄▄█   ██▄▀█ ▄█▄ ▀▄  █▀▀▄▄  ▄█▀  █
█ ▀▄ █▄▄▀█▀▀▄█▄  ██▄ ██▀▄▀▄█▄▀█▄▀ ▄█ ▄█
█ ▄▄███▄█▀▀▄▄ ▀█▄▀▀█▄▀██▀▄▀█▀ █ ▄█ ▀  █
█ ▄ ██▀▄  ▄▄▀ ▄▀▄▀▄█▄█▄█▄▄█▀ ▀▀▄ ▄██▄▄█
█  █▀ █▄▀▀▀▄██▄█  ▀█▄▀▀█ ▀▀█▀   ▀█ ▀█ █
█▀  ▄▄ ▄▀█ ▀▄█▄▀ ██▀▄██▀▄▄▄▀ █▄ █ ▀█▀ █
██▄▄▄ █▄█ ▀▄▄ ██▄▀▄██ █▀ ▀▀▄  ▄  █▄█▄▀█
█ █▀██ ▄ ▀▀ ▀ █▀ ▄█▄ ▄█▀▄██▀  █▀ █▀▄█▄█
█▄█  ▀▀▄▄▀▄▄██▄▀▀▀▄▀█ ▀█  █▀▀▄▀  ███  █
█▄▄▀█ ▀▄██▀ ▄█▄▀▄▀▄▀ ▀██ ▀▄█▄▄▄▀█  ▄█ █
█▄▄█▄█▄▄█ ▄ ▄  █ ▀▀▀▀▄▀█▀▄▀█  ▄▄▄ ▄▀ ▀█
█ ▄▄▄▄▄ █▀ █▀ ▄▄ ▀█▄▄ ▄█ ██▀▀ █▄█ █▄█ █
█ █   █ ██▄▀██ ▄▀ █▀  ▀█ ▀▀█▄▄ ▄▄  ▀▀██
█ █▄▄▄█ █ ▀ ▄█▀█▄▄█▀▄██▀▄ █▀   █▀▄▀▄█▄█
█▄▄▄▄▄▄▄█▄██▄▄▄█▄███▄▄███▄███▄█▄██▄██▄█
```
