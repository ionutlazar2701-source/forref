# Cause — CLOCK-SLEEP-006

PR #58 has no device log. The issue comments, review comments, and reviews are empty. The only physical record is the Live line from FORREF 1.0.8 on Amazfit Bip 6:

`S=ok off=0 max=0 ck=20653 r=HELD`

Screen-off still showed `TIME_UNVERIFIED`.

## What that line proves

The last successful checkpoint was 20653 ms old when the line was read. Nothing committed a newer checkpoint during that interval. The display stayed unverified because the 2500 ms rule found no observation inside the window. Elapsed time was not invented.

`S=ok` is the Device App record of `start()` returning 0. It is not `onInit`, not a `createSysTimer` callback, and not `onDestroy`.

`off=0` and `max=0` mean no callback with screen label `off` was stored. In 1.0.8 the count happens only after that label matches. A callback whose screen was `on`, `unknown`, or an API failure was discarded before it was counted. The line cannot separate a dead timer from a dropped callback.

`r=HELD` is the sample after the gap, not the gap. Once the session is unverified, `admitDisplay` returns `HELD` for every later sample and does not move the checkpoint. 1.0.8 stored that latest reason, so a prior `UNSAMPLED_GAP` is no longer visible.

## First broken link

No durable background callback was recovered inside the continuity window. That is why the clock fail-closed. The 1.0.8 witness cannot say whether the service process ran. A start code is not liveness.

1.0.9 does not change the admission rule or the foreground sampler. It records the callback before the screen read, keeps the first invalidation, and stores init, destroy, the raw screen, write attempts, write success, and readback. The 5-second wake reads that line. `L=SERVICE` with `I=0` and `n=0` means the service still left no durable execution. A different `L=` names the next link the file actually contains.
