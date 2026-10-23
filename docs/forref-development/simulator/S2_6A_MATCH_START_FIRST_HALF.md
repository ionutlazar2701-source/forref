# S2.6A — match start and first-half temporal authority

Research/reference product only. This does not change production Match Core.

## Authority

Implements the sporting subset of **FORREF TEMPORAL EVENT ADMISSION 003A** that distinguishes `MATCH_NOT_STARTED` from `FIRST_HALF_RUNNING`.

Event admissibility follows that lifecycle. It does not follow a formatted clock string. `00:00` after a lawful kick-off is active play. `00:00` before kick-off is not a football-time coordinate, and unknown time is not stored as `00:00`.

Occurrence time is frozen at Record. It is not the time at which the screen later redraws.

## What this wave implements

- `MATCH_NOT_STARTED` on the normal product scenarios `s20GoalMatchReport` and `s21MatchReportOps`
- Referee-facing **MATCH READY** and a **Kick-off** action
- `FIRST_HALF_RUNNING` after that action, with a first-half temporal anchor
- A shared one-second football clock for watch and mobile
- Admission of Goal, Yellow, direct send-off, second-caution send-off, and normal substitution only while the first half is running
- Frozen first-half occurrence (`period` + elapsed seconds). The `MM:SS` label is a projection of those seconds

Research fixtures `s01`–`s19` stay in an already-running first half so existing human-factors situations keep their operator clock. They do not arm the live ticker. `AdvanceMatchClockIntent` remains that operator control.

## Kick-off

The simulator cannot see the ball. **Kick-off** records the referee's confirmation that the lawful kick-off has just put the ball into play. Pressing the button does not cause the football match to start. The football event happens on the pitch. FORREF stores the referee-declared boundary.

One confirmation creates one anchor. A repeated press does not reset the clock or replace the origin. Focus loss, a device change, or a confirm without a fresh arm does not start the half.

## Clock

After Kick-off, the lab shell adds one monotonic second to the shared instrument about once a second. Watch and mobile read that value. The ticker does not read wall-clock time, so changing the device clock cannot move match time backwards. It also does not rebuild the lab on every frame.

The research clock is not restored after process death, and this wave does not certify OS kill, battery loss, or reboot continuity.

Ordinary goals, cards, and substitutions do not pause the clock. There is no stoppage-time model in this wave.

## Before kick-off

Normal product capture fails closed:

- Goal: prohibited
- Normal substitution: prohibited
- Yellow and both send-off pathways: not admitted, because the separate pre-match card-authority boundary is not modeled

No Match Report row is written for those refusals.

## Deferred

- **S2.6B — PRE-MATCH DISCIPLINARY AUTHORITY**
- Halftime, second-half kick-off, extra time, suspension, abandonment, post-match, and shoot-out lifecycle are not implemented and are not labeled on the report
- Exact / bounded / unresolved temporal-evidence grades are not implemented. This wave refuses an event when it has no first-half coordinate instead of inventing one

## Windows gate

```text
cd D:\forref\forref
git switch cursor/forref-simulator-s2-5-product-operations
git pull --ff-only
cd research\hf_prototype
flutter pub get
flutter run -d windows
```

Load `s21MatchReportOps`. Confirm MATCH READY, press Kick-off, let the clock run, record Home Goal `#9`, then Away Yellow `#6`. Match Report keeps those football times after the clock moves on.
