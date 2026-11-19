# FORREF-LIVE-TEL-003 evidence

Branch `cursor/live-perf-002-30fd`, pull request #52. Ancestry checked before the edit and left unmerged:

| Pull request | Head at check | Role |
| --- | --- | --- |
| #52 | `530d7d615c18f311665d3b4c8356b4126797c36c` | Starting point. Still the open PR. |
| #51 | `104bb21c4f28f6625273f9a8d7567669fbcee6f8` | Base of #52. Confirmed ancestor. |
| #49 | `7bc491941360b4c52c87f2b6794780815a21005a` | On the same history. |
| #48 | `4510c948439759d08c1dde4d6c2fb503d98b2cb8` | On the same history. |
| #44 | `c993055fbeb4e769174aaf86d5aa4889ee95c21d` | Stack base recorded by GitHub. |

Functional commit: `62f57dabe5d523bdc5fd0e6833331bdde13c7468`.
Boot name: `live-tel-003`.

No pull request was merged.

## Gate matrix

| Gate | Result | Evidence |
| --- | --- | --- |
| T01 Clock first | PASS | `telemetry.test.js`: constructor and storage write stay at 0 until the deferred turn; a pause before that turn never calls `Geolocation`. `followClock` does not construct the SDK. |
| T02 Clock regressions | PASS | `match_clock.test.js` inside the watch suite (75 tests, 0 failed) plus the kick-off → full-time chain. |
| T03 HR live | PASS in unit tests. Guest injection not run. | Fresh `142` is `HR 142 bpm` / `PULS 142 bpm`. `getLast()`, `20`, and a sample older than 15 s are not live. GPS constructor failure still delivers HR. |
| T04 GPS quality | PASS | Searching, permission, weak `0` satellites, invalid coordinates, lost fix, teleport, and a new anchor are covered. The 4 m hold is still `advanceDistance`. |
| T05 Distance / half-time | PASS | Fifteen minutes of half-time movement add 0. Second half starts from a new anchor. Total is first + second. Added time counts only while the phase stays running. |
| T06 Pause / suspend | PASS | Pause, suspension, and `TIME_UNVERIFIED` add 0 and do not bridge. |
| T07 Races | PASS | Old generation, observation time before the open interval, uncertain provenance, and a callback left from the previous half add 0. Immediate pause cancels the scheduled GPS start. |
| T08 Listeners | PASS | Strict mock throws unless `offChange` / `offCurrentChange` / `offGnssChange` receive the registered function. Pause and half-time cycles keep one HR listener. A thrown `offChange` is marked degraded and does not register a second GPS listener. `hr.start` / `hr.stop` are not called. |
| T09 Navigation | PASS in unit tests. Guest route walk not re-run. | `pageExit` does not stop sensors. Live `onDestroy` does not release them. App `onDestroy` does. |
| T10 Storage | PASS | `NOT_FOUND`, `READ_FAILED`, `CORRUPT`, `SHORT_WRITE`, `CAPACITY`, `CONFLICT`, and an empty kick-off id are distinct. Restore happens only when the kick-off id matches. The file is `forref_tel_003_state.txt`. |
| T11 Stress | PASS | 5,000 GPS callbacks do not write per sample. Twenty pause/resume cycles keep one listener pair. No track is retained. |
| T12 UI / locale | PASS for geometry and copy. Guest frames not recaptured. | `~0,15 km` / `~0.15 km`, `— km` before the first anchor, numeric HR only when fresh. Slot stays above the team controls on 390×450 and 480×480. |
| T13 Production isolation | PASS | No Match Memory write, `distanceSaved` stays false, no `getSportData`, no `data:user.hd.workout`, no heat map, 23 routes, app id 29566. |
| T14 Build / cloud | PASS for repository suites and the Bip 6 package. Guest simulator not connected. | Commands below. |
| T15 Physical Bip 6 | LOCAL GATE REQUIRED | No physical watch was attached. |
| T16 Screen-off / 90 min | NOT CERTIFIED | Not run. Not claimed. |

## Commands

Watch suite, from `apps/forref_watch_zepp`:

`node --test test/*.test.js` → 75 tests, 0 failed.

Sensor lab, from `apps/forref_sensor_lab`:

`npm test` → 34 tests, 0 failed. Includes the 3 m / 4 m held-anchor case.

Repository cloud gate, from the repository root:

`./tool/verify_cloud.sh` → exit 0.

- Match Core: 377 tests passed
- Persistence: 92 tests passed
- Phone: 126 tests passed

Package, from `apps/forref_watch_zepp`, Zeus 1.10.0:

`zeus build -t "Amazfit Bip 6"` and `zeus preview -t "Amazfit Bip 6"`.

Device sources `9765120`, `9765121`, `10158337`. Package `29566-FORREF-1.0.2-20261119212654.zab`. sha256 `bfcefa1e6fca63a3c272ed40e2c8e66210f3146141a524cd3d899b5d87568bed`. Manifest: app version 1.0.2 code 2, square `390x450`, cpu `ZPS`.

`zeus status` before preview: simulator `disconnected` on `127.0.0.1:7650`. No guest frames were captured in this run. The earlier #52 screenshots are not evidence for this build.

GitHub Actions was not treated as this run's CI result.
