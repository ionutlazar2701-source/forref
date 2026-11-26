# CLOCK-UI-CADENCE-001 root cause

Live Match keeps the correct elapsed time and sometimes paints it only every other second. The skip continues until another sleep or navigation schedules the timers again.

## What is wrong

Two independent `createTimer(1000, 1000)` callbacks were alive whenever Live was open:

- `app.js` starts `startForegroundClock()`, which calls `sampleFromScheduler("fg")`.
- `page/gt/live/index.page.js` started its own timer, which called `paintAll()` → `prepareFrame()`.

Each callback asks the runtime for a 1-second wake. They do not share a phase. After a cold start they often wake together, so the digits change every second. After screen sleep or a page rebuild the runtime can resume them half a period apart. The paint callback then runs at 0 ms, 2000 ms, 4000 ms, while the foreground sampler runs on the opposite second. The face steps by two seconds and stays on that phase until the next sleep or navigation creates the timers again. That matches a cadence that appears after a transition and can be cleared by another transition.

The UTC anchor is not the cause. A paint at `now` still shows `closed + (now - openStartUtc)`. A missed paint does not add a second and does not subtract one. The next paint shows the anchor time, including the second that was not drawn.

`commit` on a healthy `utc_segment` paint stays skipped (`reason` `UTC_ASSUMED`, `commitMs` 0). The 2-second face was not a persistence failure.

## Timestamped device evidence already on file

`docs/forref-execution/evidence/zepp-live-match-flow-002/rectangular/console-bip6.txt` is a Bip 6 log (`deviceSource=10158337`) from build `live-match-flow-002`. That build had the Live page timer only. It shows one skipped paint in an otherwise 1-second run, using the console timestamps as recorded:

| Console stamp | Display |
| --- | --- |
| 20:58:16.910 | `00:15` |
| 20:58:18.915 | `00:17` |

The gap is 2005 ms and the drawn second jumps by 2. The next lines return to about 1000 ms (`00:18`, `00:19`, `00:20`). That is a single missed paint, not the persistent phase split. The persistent split needs the second timer, which this later clock stack added in `clock_foreground_bind.js`.

## How the patch tells the two failures apart

Each foreground tick logs one line. `utc` is `Time.getTime()` at the start of the callback. `dt` is the gap since the previous callback. `prepareMs` is the admission time with the slot write removed. `commitMs` is that slot write (`0` when a healthy segment is not rewritten). `paintMs` is `paintDigits()`.

```
FORREF_CLOCK_CADENCE utc=… dt=… prev=… now=… step=… prepareMs=… commitMs=… paintMs=… timers=1
```

| Classification | `dt` | `step` | Meaning |
| --- | --- | --- | --- |
| `ONE_SECOND` | about 1000 | 1 | Callback and face both advance one second. |
| `CALLBACK_2S` | about 2000 | 2 or more | The callback itself is on a 2-second phase. |
| `RENDER_SKIP` | about 1000 | 2 or more | The callback is on time and the widgets skipped a second. |

`classifyCadence` encodes those bands. A 2-second phase is not reported as a render skip.

## Patch

Live no longer creates a timer. It binds a paint listener to the one foreground timer. Returning to Live calls `restartForegroundClock()`, which stops that timer and arms one new `createTimer(1000, 1000)`. A failed `stopTimer` keeps the existing id and does not arm another. Leaving Live unbinds the paint and leaves the sampler running, so capture pages still get one sample per second. The tick samples once and paints that view. It does not call `prepareFrame` a second time.

No UTC-segment rule, trust label, or slot commit changed. A missed tick is not filled in.

## CPU and battery

While Live is visible this replaces two 1-second JavaScript wakes with one. Each wake does one admission and one `paintDigits`, not an admission from the app timer plus another admission and a paint from the page. A healthy segment still does not rewrite its slot on that wake (`commitMs` 0). `createTimer` still stops when the screen is off. No `createSysTimer` was added, so screen-off does not gain a new wake. Expected on-wrist cost while the screen is on is lower or equal. This run did not measure CPU or battery on a watch.
