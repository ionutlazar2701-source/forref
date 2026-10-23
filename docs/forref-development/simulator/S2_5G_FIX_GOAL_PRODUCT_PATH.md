# S2.5G-FIX — Goal scored product path

## Incident

Founder SimLab showed `Saving — simulated` and `In flight: goal p-away-11` while the live score stayed `0–0`.

## Cause

`Record Goal` only freezes the command (`SystemCommitKind.saving`). Establishing the goal required a second action, `Resolve simulated outcome`.

That second control is on the watch reference while saving. The mobile session pane, which renders “Recent research state” and “In flight”, had no resolve control. The normal Founder press therefore never called `resolveSimulatedCommit`, so no `SavedGoal` was written and the score projection stayed `0–0`.

The geometry-stage pointer path already resolved on pointer-up unless hold was set. Watch and mobile buttons did not.

## Product fix

For `PresentationAction.goal` only, when the scripted outcome is **success**, the presentation runtime finishes the existing frozen-command commit in the same intent:

activate → `resolveSimulatedCommit` → `SIMULATED SAVED — not production D1` → Live.

Score and Match Report still come from the established `SavedGoal`.

Known failure and unknown stay in `Saving — simulated` until an explicit resolve. They do not become success.

Yellow, send-off, and substitution are unchanged and still use the separate resolve step.

## Deferred

`HUAWEI · Watch GT 4 · 46 mm` showing `LAYOUT NOT FIT FOR THIS PROFILE` is **NON-GOAL PRODUCT ISSUE — DEFERRED**. Goal validation uses the mobile pane and a fitting watch profile (Amazfit GTS 4).

## Windows retest

```text
cd research\hf_prototype
flutter pub get
flutter run -d windows
```

Load `s21MatchReportOps`. Live `0–0`. Away goal `#11`, Record Goal. Expect `SIMULATED SAVED`, score `0–1`, one Match Report goal. Then Home `#9`. Expect `1–1` and a second goal row. No Inspector. No “Resolve simulated outcome”.
