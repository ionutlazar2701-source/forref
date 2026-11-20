# Hardware gate — clock sleep 002

Cloud PASS is not hardware certification. This VM did not run Amazfit Bip 6 screen-off.

## Physical result already recorded for FORREF 1.0.4

| Check | Result |
| --- | --- |
| Screen-off 5 s | FAIL |
| Screen-off 30 s | FAIL |
| Screen-off 120 s | FAIL |
| Match Controls | NOT TESTED |
| HALF-TIME / PAUSE | FAIL, symptom not classified on device |

That build's service start was unreachable because `queryPermission` was called with a callback the API does not document. The cloud tests now fail that shape and pass the synchronous contract. They do not show that `createSysTimer` fires, or that a checkpoint is readable, while the Bip 6 screen is off.

## Still unproven on device

- `queryPermission` returns `2`, or the request callback returns `2`, on this watch.
- `start-code=0` and `start-cb=true`.
- `getAllAppServices` lists `app-service/clock_service`.
- `createSysTimer` logs `tick=` with `screen=off` across a real screen-off.
- The checkpoint `last` advances during that interval and the wake display matches it.
- A committed pause stays paused after the service has been running.

Until those lines are captured, device continuity stays LOCAL GATE REQUIRED. A missing tick, `perm=unknown`, `perm=denied`, `start-code` other than `0`, or `readback` other than a successful readback means the clock must stay unverified. Do not treat a quiet screen-off as played time.

## Diagnostic identity

- App 29566, version 1.0.5 (code 5), `FORREF CLOCK SLEEP DIAGNOSTIC`
- `build=clock-sleep-002`
- `rev=0b083a940b45943b6c0be5ee358005c572ac6ac5`
- Package `29566-FORREF-1.0.5-20261120214202.zab`
- sha256 `1644b8240e02071a63dcf93b6aa384847467aaa769a052e84dd89c1f2d69619d`
- Simulator connect status: disconnected. No on-screen frames.
