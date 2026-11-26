# CLOCK-UI-CADENCE-001 Bip 6 protocol

State: **NOT TESTED**. Fill every row on a physical Amazfit Bip 6. Cloud tests do not paint the watch face.

App id `29566`, version `1.0.12` (code 12). Install the preview in `CADENCE_PREVIEW_QR.txt`. Zeus preview target Amazfit Bip 6, device sources 9765120, 9765121, 10158337. Package `29566-FORREF-1.0.12-20261126191835.zab`, 304907 bytes, sha256 `2c0c7d7c2f6e8e8004779d6d2f01e990cf8dcab18e8ccae6e4806dab20ffe50e`. Built from commit `71f7263d19040619c3e9ab0badf4384c66aae6a1`. The boot line names `6fb764864e13dc21b8ce3f6484c4644aeff2962d`. The QR expires 3 December 2026, 21:18:38 Europe/Bucharest (19:18:38 UTC). The previous `1.0.11` package is the build that still has two 1-second timers. The rows below stay **NOT TESTED** until a physical Bip 6 runs them.

## What to record

Keep the developer log. For each running stretch, copy the `FORREF_CLOCK_CADENCE` lines. A healthy stretch has `dt` near 1000, `step=1`, and `timers=1` for at least five consecutive ticks. `commitMs=0` during ordinary running is expected for a healthy UTC segment. Hidden digits remain `TIME_UNKNOWN`. Do not treat a smooth face as `PROVEN_TIME`.

Also note battery percent at the start and end of the 10-minute row. That number is an observation of this package, not a certification.

## Trial matrix

| Test | Steps | Pass | Result |
| --- | --- | --- | --- |
| TICK | Kick off. Leave the screen on for 30 s. | Five or more cadence lines with `dt` 700–1400 and `step=1`. The face matches a reference stopwatch within 1 s. | NOT TESTED |
| SLEEP | Screen off for 30 s, 2 min, then 10 min. Wake into Live each time. | After each wake, the first face matches the reference, then five `step=1` lines. The 2-second phase does not stick. | NOT TESTED |
| NAV | From Live open Goal, Card, Substitution, and Match Controls, then return. Repeat three times. | Each return shows the anchor time, then five `step=1` lines. | NOT TESTED |
| REPEAT | Sleep, navigate back, sleep again. | None of the three returns stays on `step` 2. | NOT TESTED |
| PAUSE | Pause for 20 s, resume. | Paused face is frozen. After resume, `step=1`. The paused gap is not in the match time. | NOT TESTED |
| MISS | If a single `dt` near 2000 appears, read `now`. | `now` equals the reference at that instant. The next lines return to `step=1`. The skipped second is not inserted afterwards. | NOT TESTED |
| BATTERY | Same 10-minute sleep row. | Start and end percent. Screen was allowed to sleep. | NOT TESTED |

`CALLBACK_2S` on five consecutive lines after a wake or a return fails this protocol. `RENDER_SKIP` on five consecutive lines also fails it: the callback is on time and the widgets are dropping a second, which this patch does not claim to have fixed.
