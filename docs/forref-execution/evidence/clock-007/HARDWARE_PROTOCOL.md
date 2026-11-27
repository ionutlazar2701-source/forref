# CLOCK-007 Bip 6 protocol

State: **NOT TESTED**. Fill every row on a physical Amazfit Bip 6. Unit tests do not certify the watch.

App id `29566`, version `1.0.16` (code 16), boot `build=clock-007 rev=bb38321f87998a2c9a68b073ef6c8ee3e979bb30`. Install the package built from this branch. The v1.0.15 package is the build that still keeps the slept timer.

## Two measurements

Keep them separate.

Cadence comes from `FORREF_CLOCK_CADENCE` and the first twenty `FORREF_CLOCK_WAKE` lines after each wake. `dt` is the gap between callback UTC stamps. `step` is the change in the drawn digits. `prepareMs`, `commitMs`, and `paintMs` are on the same line. `timer=on`, `timer=off`, and `timer=wake` are the create, stop, and replacement events. `page=build`, `FORREF_PAGE live onInit`, `FORREF_PAGE live onDestroy`, `FORREF_APP onCreate`, and `FORREF_APP onDestroy` are the lifecycle lines. `screen=` is logged only when a callback sees the screen value change.

Elapsed time is a separate stopwatch, started at kick-off. At each reading, write the stopwatch and the drawn face. The face may jump once by the slept amount. After that it must agree with the stopwatch within 1 second. That 1 second is the display tolerance from the cadence protocol. Do not judge elapsed time by `step`.

| Classification | `dt` | `step` | Meaning |
| --- | --- | --- | --- |
| `ONE_SECOND` | 700–1400 | 1 | Callback and face both advance one second. |
| `CALLBACK_2S` | 1500–2600 | 2 or more | The callback itself is on a 2-second period. |
| `RENDER_SKIP` | 700–1400 | 2 or more | The callback is on time and the digits skipped a second. |

A single catch-up row after sleep is the anchor, not the cadence. The following rows are the result. `TIME_UNVERIFIED` on any row fails that trial. Five `CALLBACK_2S` rows after the catch-up fail the trial. Five `RENDER_SKIP` rows fail it too: this correction replaces a slow timer and does not drop or invent a paint.

## Trial matrix

Watch the log for 30 seconds after each return before starting the next row.

| Test | Steps | Pass | Result |
| --- | --- | --- | --- |
| TICK | Kick off. Leave the screen on for 30 s. | Five or more cadence lines with `dt` 700–1400 and `step=1`. Face within 1 s of the stopwatch. | NOT TESTED |
| SLEEP-10 | Screen off for 10 s. Wake into Live. | One catch-up to the stopwatch, then 30 s of `step=1`. One `timer=wake` or `timer=on` for the replacement. `timers` stays 1. | NOT TESTED |
| SLEEP-60 | Screen off for 60 s. Wake into Live. | Same as SLEEP-10. The drawn face matches the stopwatch within 1 s, not a 2 s ladder. | NOT TESTED |
| SLEEP-5M | Screen off for 5 minutes. Wake into Live. | Same as SLEEP-10. | NOT TESTED |
| APP | Switch away and return to Live. | `page=build` then one timer replacement, then 30 s of `step=1`. The face matches the stopwatch within 1 s. | NOT TESTED |
| NOTICE | Open a notification and return. | Same as APP. No `TIME_UNVERIFIED`. | NOT TESTED |
| GOAL | After one wake, record one local-test goal and confirm it. | The score follows the existing local-test path. The clock rows after the confirm stay `step=1`. | NOT TESTED |

`CALLBACK_2S` on five consecutive lines after the catch-up means the replacement did not recover the period. Copy those twenty wake lines into this file. Do not mark the row passed from a face that looks smooth.
