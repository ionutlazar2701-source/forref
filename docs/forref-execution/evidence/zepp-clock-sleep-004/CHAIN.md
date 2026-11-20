# Screen-off evidence chain — CLOCK-SLEEP-004

Physical input from FORREF 1.0.6 on Amazfit Bip 6:

- Goal, Card, and Substitution kept the match clock.
- Match Controls kept the match clock.
- Leaving FORREF and reopening it in the same match kept the match clock.
- Screen-off still ended in `TIME_UNVERIFIED`.

No device log from that run was returned, so the broken link is not named yet. 1.0.6 proved the foreground sampler. 1.0.7 does not replace it. It prints the first broken link of the screen-off chain.

`DISPLAY_CONTINUITY_MS` stays 2500. A label in the log is not elapsed time.

## What each line means

| Line | Broken link it can show |
| --- | --- |
| `perm=` `request=` `request-cb=` `start-code=` `start-class=` `services=` `host running=` | The service was not allowed to run, `start` failed, or the running list does not contain it. `start-class=permission` is a grant failure. `start-class=ok` only means the start call was accepted. |
| `service=init` then `service=on timer=on id=` | The service module loaded and `createSysTimer` returned an id. `timer=unavailable` or `timer=null` means the timer was not created. |
| `tick=` `dt=` `step=` `utc=` `screen=` `class=` `file=` `mirror=` `pair=` | One callback. `dt` is the gap since the previous callback. `step` is the gap since the last admitted UTC. `screen=off` is required during the sleep. `pair=match` means the file and the mirror both read back equal and non-empty. |
| `service=off reason=stop` or `reason=destroy` | The service exited. `stop` is our halt. `destroy` is the system ending it. `phase` and `trust` say whether that was a whistle or an unverified clock. |
| `stop-reason=phase` or `stop-reason=unverified` | The device app asked the service to stop. A pause is `phase`. An already unverified clock is `unverified`. |
| `edge=off` and `edge=on` | Last foreground observation as the screen changes, and the first observation after it comes back. |
| `recover=` `step=` `notice=` | `loadSession` after the app is created again. `CONTINUITY_RESUMED` keeps the open segment. `RECOVERY_REQUIRED`, `UNSAMPLED_GAP`, and `CONFLICT` do not add the gap. |

## One label for the sleep

Take the screen-off ticks and the wake `recover=` line:

| Evidence | Label |
| --- | --- |
| No `service=on` | `SERVICE` |
| `service=on` and `timer` is `null` or `unavailable` | `TIMER_CREATE` |
| Timer on, and no `tick=` with `screen=off` during the sleep | `TIMER_SILENT` |
| An off tick with `class=TIMER_GAP` or `dt` greater than 2500 | `TIMER_GAP` |
| An off tick with `class=PERSIST`, `file=fail`, `mirror=fail`, or `pair=miss` | `PERSIST` |
| Off ticks are `class=CHAIN` with `pair=match`, and wake is `CONTINUITY_RESUMED` | `CHAIN` |
| Off ticks are `class=CHAIN`, and wake is `RECOVERY_REQUIRED`, `UNSAMPLED_GAP`, or `CONFLICT` | `RECOVERY` |

The first of those that matches is the break. A later label does not override an earlier one.
