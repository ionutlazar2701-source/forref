# CLOCK-004 findings

Isolated research app `CHRON-004`, app id `30104`. Production FORREF (`29566`) and `DISPLAY_CONTINUITY_MS = 2500` in `apps/forref_watch_zepp/utils/match_clock.js` are unchanged. This package is not a Match Record and it does not write Match Memory.

## Verdict

| Question | Result |
| --- | --- |
| Can a stored UTC anchor rebuild elapsed time after the page stops running? | Arithmetic yes. The Node suite reconstructs 30 s, 2 min, and 10 min from `anchorUtc` with no callback count. |
| Is that display `PROVEN_TIME`? | No. Every successful read is `UTC_ASSUMED` with reason `WALL_CLOCK_CONTINUITY_UNVERIFIED`. |
| What happens if the phone changes the clock while the page is alive and the segment is running? | `onPhoneTimeSetting` stores `TIME_UNKNOWN` / `PHONE_TIME_SETTING`. The digits are replaced by `TIME UNKNOWN`. |
| What happens if civil time steps while the process is dead? | One later `Time.getTime()` cannot see the step. The display stays `UTC_ASSUMED` and can be wrong. That row is a required hardware observation. It must not be promoted to `PROVEN_TIME`. |
| Hardware | **NOT TESTED.** The preview package below is installable. No Bip 6 sleep, relaunch, pause, or clock-step row has been filled. |

## API corrections before the Bip 6 build

Zeus `1.10.0` rejected the prototype's root `icon.png` (`The icon in app.json is empty or the image does not exist`). The icon now lives at `assets/gt.s/icon.png`, which is where a `gt` / `st: "s"` target is loaded. Zeus resized it to 124 px and compiled the package for device sources `9765120`, `9765121`, and `10158337`.

`readFileSync` is documented to return a `string` or `undefined` when the file cannot be read. It does not return an ENOENT exception for a missing slot. The page maps `undefined` and a thrown read to an empty string, so the first launch is `EMPTY` and can take `START`. A torn string still fails closed as `CORRUPT`. `writeFileSync` is documented to return `void`, so the commit succeeds only after the same bytes read back.

The device library copies record fields explicitly. The prototype's object spread and optional `catch` bindings are not in the device sources. `QJSC` compiled both bundles.

The page uses the documented calls `Time.getTime()`, `Time.onPhoneTimeSetting`, `Screen.onChange`, `setWakeUpRelaunch({ relaunch: true })`, `getDeviceInfo()`, and `setInterval` from `@zos/timer`. The one-second timer only increments `ticks`. It is not added into the displayed duration.

## Bip 6 layout

`designWidth` is `390`. Content starts at y = 64, under the status bar used by the other Bip 6 probes. The clock, status, detail, diagnostic, and both buttons stay inside 390×450, and the buttons sit below the diagnostic line. Button captions follow the watch language (`en-US`, with Romanian when `getLanguage()` is `21`). Phase names and the trust labels `UTC_ASSUMED` and `TIME_UNKNOWN` stay in the protocol vocabulary.

## Package

| Field | Value |
| --- | --- |
| Command | `zeus preview -t "Amazfit Bip 6"` |
| Package | `30104-CHRON-004-1.0.0-20261121111810.zab` |
| Bytes | 16084 |
| sha256 | `4270480f665e43c1ff4544c25d99a06e606cff659a0c9c8d5486b9dcb1050f10` |
| QR expiry | 28 Nov 2026, 13:18:13 Europe/Bucharest (11:18:13 UTC) |

The scannable code is `CHRON004_PREVIEW_QR.png`. Scan it from the Zepp app on the phone paired to the Bip 6. Developer mode has to be on. This app is `CHRON-004`, not production FORREF.

## Node tests

`npm test` in `apps/forref_chron004_probe`: 14 passed, 0 failed. The suite covers the 30 s / 2 min / 10 min reconstructions, the undetectable sleep-time civil step, phone-time fail-closed, pause / half / second half, two-slot damage, stale writes, restart of the same anchor, layout bounds, and the separation from app id `29566`.
