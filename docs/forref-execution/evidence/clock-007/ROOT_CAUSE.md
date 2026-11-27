# CLOCK-007 root cause

Classification: **CALLBACK_2S**. Software reproduction only. The Bip 6 log that confirms or overturns this classification has not been captured. A smooth face is not the evidence.

## What persists after sleep

v1.0.15 already has one Live timer. `page/gt/live/index.page.js` does not call `createTimer`. It binds a paint listener and calls `restartForegroundClock()` from `build()`.

Screen sleep does not destroy the Live page, so `build()` does not run again. The foreground `createTimer(delay, 1000, run)` stays armed. `createTimer` stops while the screen is off and is not the screen-off clock. When the screen returns, that same timer id resumes. In the platform model used by the test, a timer that was already armed at the start of sleep then fires at twice the delay it was given, and it keeps that period until `stopTimer` deletes the id. A timer created after that mark keeps the delay it was given.

Each resumed callback still samples UTC. The digits are that sample. A 2-second callback therefore draws a face two seconds ahead of the previous face, and the next callback does it again. That is a persistent `step` of 2 with `dt` near 2000. It is not `TIME_UNVERIFIED`, and it is not an inserted or removed second. The first callback after a long sleep is one catch-up to the anchor. The rows after that catch-up are the cadence.

`RENDER_SKIP` would be `dt` near 1000 and `step` of 2 or more. The paint path updates the digit widget on every callback. The software model does not produce that pattern. The wake log is what separates the two on the watch.

## What the correction does

A callback whose `dt` is at least 1500 ms stops the timer that just fired and arms one replacement. The delay is `nextTimerDelay` to the next UTC second. The sample for that callback is taken before the replacement and is not adjusted. A callback whose `dt` is near 1000 does not replace the timer, including one that skipped a displayed second. A failed `stopTimer` does not arm a second id.

Returning to Live still calls `restartForegroundClock()`, which is the same one-id replacement. The first 20 callbacks after that restart, and the first 20 callbacks after a gap, are copied to `FORREF_CLOCK_WAKE` lines. Those lines are `console.log`. A healthy frame does not write a diagnostic file.

Elapsed time is still `closed + (utc - openStartUtc)` from the UTC segment. A missed callback is not filled in.

## What this does not change

Goal, score, Match Memory, and the `TIME_UNVERIFIED` fail-closed path are untouched. CLOCK-006 observation mode is not treated as certification. No second Live timer and no `createSysTimer` were added.
