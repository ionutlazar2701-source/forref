# CLOCK-007 software results

State: **SOFTWARE PASS / HARDWARE GATE PENDING**. Not a hardware pass.

Functional commit `bb38321f87998a2c9a68b073ef6c8ee3e979bb30`. Boot name `clock-007`.

## Reproduction

The test platform doubles the period of a timer that is already armed when sleep begins. A timer created afterwards keeps its requested delay.

A host that never stops that id produces, after a 10-second sleep, one catch-up to `00:15` and then `dt=2000` `step=2`. `classifyCadence` returns `CALLBACK_2S`. One timer remains.

The foreground host stops that id when `dt` is at least 1500 ms and arms one replacement. For sleeps of 10 seconds, 60 seconds, and 5 minutes the catch-up face equals the UTC projection at that callback. The next callbacks have `dt=1000` and `step=1`. The drawn second is the anchor second. It is not the previous second plus one, and it is not the anchor minus two.

A callback every 1000 ms whose digits jump by two is `RENDER_SKIP`. That path does not stop the timer. A `stopTimer` that throws on the gap does not arm a second id. Returning to Live after sleep leaves one timer, and the next gaps are 1000 ms. The wake lines carry `dt`, `step`, `prepareMs`, `commitMs`, and `paintMs`. No diagnostic file is written.

## Suite

`npm test` in `apps/forref_watch_zepp`: 239 pass, 0 fail.

Goal, score, and Match Memory files are not in the functional diff.
