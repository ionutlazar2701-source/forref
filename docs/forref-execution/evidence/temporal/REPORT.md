# Temporal precision attack

Actual model: Grok 4.7 (session identity). Requested preference: `grok-4.7-high`. Cloud run metadata `originalModelName` was null, so no separate high-tier id was returned.

Branch: `cursor/forref-wave1-temporal-attack-30fd`

Base SHA: `919c9062d607f0af255ad368b8c6cb2658d6c85a`

Attack tests ran at SHA: `db7d7c7cada7a14b1c8285baad0a2380cb25d34b`

This report is a later commit on the same branch. It does not change production code.

No physical device was available. `TemporalEvidence.certified: true` was used only as an input flag. It is not hardware clock certification.

**LOCAL GATE REQUIRED:** hardware monotonic-clock certification (drift, background throttling, OS timer policy) and power-loss durability during D1 commit. See `docs/local-gates.md`. This run does not certify either.

## Scope

Adversarial tests against the existing pure-Dart elapsed projection. No temporal policy change. No `lib/` edit. No persistence, phone app, watch UI, pubspec, or `tool/` change. Existing tests were not edited.

Projection under test: `deriveActivePeriodElapsed` in `packages/forref_match_core/lib/projection/active_period_elapsed.dart`, fed by `DeterministicMatchProjector` and `TemporalMatchProjection.derive`.

## Commands

`fvm` is not installed. Repo-root `.fvm/fvm_config.json` exists (`flutter: 3.47.2`). `packages/forref_match_core/.fvm/fvm_config.json` does not. Suites used `dart test` (Dart SDK 3.13.2) from `packages/forref_match_core`.

- `dart test test/adversarial/temporal_recovery_attack_test.dart` — 25 passed, 0 failed.
- `dart test --reporter expanded` — 163 passed, 0 failed. That count includes the 25 new tests plus the existing package suite.

Both commands exited 0 on SHA `db7d7c7cada7a14b1c8285baad0a2380cb25d34b`.

## Result

No HOLD. Every attack passed on unchanged production code. No attack produced a false exact elapsed or a false period end.

`pastRegulationDisplayThreshold: true` occurred only for exact continuity at or past `Duration(minutes: 45)`, and in those cases `periodEnded` stayed false unless a committed `PERIOD_ENDED` record existed. An early `PERIOD_ENDED` at 12 seconds stayed 12 seconds when a later sample crossed 45:00, and the display flag stayed false.

## Demonstrated

These behaviors were reached through the public API.

- `ActivePeriodElapsedProjection.unavailable` is `continuityUnresolved`, `ProjectionTrust.untrusted`, `certified` false, `precisionSafeToShow` false, both elapsed bounds null, `exactElapsed` null, and `periodEnded` false.
- An empty committed set plus a certified 90:00 sample equals that unavailable constant.
- Unresolved continuity, with null exact elapsed, null bounds, and `precisionSafeToShow` false, was reached for: a forged anchor id that is not the committed evidence id; a missing monotonic or a null continuity domain (wall clock was not subtracted); a reversed monotonic; an interval that starts before the anchor; continuity domain ids that differ only by case; incomplete temporal trust; conflicted temporal authority; and match start with no period.
- Incomplete and conflicted readings are unresolved and uncertified, and they are not equal to the unavailable constant, because their trust is not `untrusted`.
- Exact 45:00 sets the display flag and leaves period 1 active. One microsecond under 45:00 is not rounded up. An exact 1500 milliseconds stays 1500 milliseconds.
- A certified flag on the evidence does not set `elapsed.certified`.
- A wall clock past 90 minutes with a 10-second monotonic does not end the period.
- A bounded span around 45:00, a zero-width interval at exactly 45:00, and an interval wholly past 45:00 stay `boundedContinuity` with `exactElapsed` null, `precisionSafeToShow` false, the display flag false, and `periodEnded` false.
- An open suspension whose boundary is 45:01 keeps that exact playing elapsed, sets the display flag, and does not end the period or adopt a later 2-hour sample.
- The same committed records produce exact continuity or bounded continuity from the evidence shape, never both. An exact playing segment plus an interval sample stays bounded (20–25 seconds here), not one collapsed exact elapsed.
- Six rebuilds (two projector instances and three record orders, including a period record that sorts before match start) were equal. An ended period stayed at 25 seconds across live samples of 25 seconds, 45:00, and 3 hours. Different `recordedAt` values did not change elapsed.

## Hypotheses

Not demonstrated failures. Not asserted as defects.

- Power loss during D1 commit was not exercised. **LOCAL GATE REQUIRED.**
- Device-clock drift and OS timer policy were not measured. **LOCAL GATE REQUIRED.** `certified: true` on evidence did not certify the projection.
- Watch or phone timer rendering was not built. Timer rendering is not temporal authority.
- `deriveActivePeriodElapsed` trusts caller-resolved `TemporalEvidence` for a committed evidence id. Swapping the artifact behind an id is an admission question, not a result of this run.
- `TemporalContext.domainClockPolicyVersion` is not read by this derivation. Existing elapsed tests already pin a version and still compute elapsed. No failure was asserted.
- Duplicate evidence ids and empty-string continuity domain ids were not asserted. The derivation compares non-null domain ids and takes the first matching evidence id in `recordedEvidence`.
- `precisionSafeToShow` stayed true for an exact 1500-millisecond reading. The stored elapsed was not rounded. A consumer that truncates that value to a whole second would show a second the evidence does not state. The projection did not do that truncation.
- A bounded interval whose whole range is past 45:00 does not set `pastRegulationDisplayThreshold`. That matches the field comment: the flag is for exact elapsed. It is fail-closed against false exactness, not a missed period end.

## Gates

- IMPLEMENTATION: no production change. `lib/` was not patched.
- TEST EVIDENCE: 25 new tests and the full `forref_match_core` suite passed on the SHA above.
- DOMAIN AUTHORITY: display threshold is not `PERIOD_ENDED`. Unresolved and bounded readings do not present one exact elapsed. Unavailable stays untrusted and uncertified.
- ARCHITECTURE: projection stayed disposable and rebuildable. No Match Memory mutation and no second writable authority.
- HUMAN FACTORS: no UI. The 45:00 flag is display-only in the projection under test.
- RELIABILITY: reachable attacks did not yield false exact elapsed or false period end. Rebuilds of the same records matched. Hardware clock and power-loss certification remain **LOCAL GATE REQUIRED**.
- INTEGRATION: package tests only. No phone, persistence, SQLite, or watch integration.
