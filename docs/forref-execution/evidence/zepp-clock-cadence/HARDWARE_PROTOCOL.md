# CLOCK-UI-CADENCE-001 Bip 6 protocol

State: **NOT TESTED**. Fill every row on a physical Amazfit Bip 6. Cloud tests do not paint the watch face.

App id `29566`, version `1.0.12` (code 12). This cloud run did not produce an installable package: Zeus CLI 1.10.0 opened a Zepp login page and this environment has no saved session. Build the preview from this commit on a logged-in machine with `zeus preview -t "Amazfit Bip 6"`, then install that package. The previous `1.0.11` package is the build that still has two 1-second timers.

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
