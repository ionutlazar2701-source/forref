# WAVE 1 adversarial report

Saboteur agent: Grok. Run `bc-eebe680c-ceaa-576b-86a3-f9ade6c100a4`.

Parent at launch: `a1ae8f98e676417590611691d0e121b1cc68ad25`.

Branch: `cursor/forref-wave1-saboteur-30fd`.

The saboteur added tests only. It did not edit `lib/`.

## Agent result

SABOTEUR HOLD.

Reproducible defect: `evaluateCaptureIntentAdmission` compared `AuthorityScope` by identity. Two separately constructed `MainRefereeScope` values did not compare equal, so one `captureIntentId` could be admitted twice in memory.

Failing tests at that HOLD:

- `separately constructed MainRefereeScope values cannot split one capture intent into two goals` expected 1 `GoalPayload` and observed 2.
- `separately constructed MainRefereeScope values still conflict for a different scoring team` expected `CaptureIntentConflict` and observed `CaptureIntentFirstAdmission`.

The SQLite admission key is the `MAIN_REFEREE` wire string. That path did not append a second row for the same intent.

## Remediation

Orchestrator fix, not a saboteur edit of production code: `d31f1d1e7459649e62d01b73a42cb2f74d8e51a7`.

`MainRefereeScope` equality is value equality. `hashCode` is the `MAIN_REFEREE` wire hash. `commitGoal` rejects `authorityGeneration != 1`.

The saboteur commits were fast-forwarded onto `cursor/forref-wave1-goal-score-30fd`:

- `183749e4db519ae151efd8f39c865690821aa5a1` attack tests
- `488289d94c7e48120ade102f1dabfe0d1e125131` period identity on the integrity fixture
- `d31f1d1e7459649e62d01b73a42cb2f74d8e51a7` scope-value fix

## Re-execution

After the fix, on the integrated tree:

- `cd packages/forref_match_core && dart test test/adversarial/wave1_goal_saboteur_test.dart` — 11 passed.
- `cd packages/forref_match_persistence && dart test test/wave1_goal_saboteur_test.dart` — 3 passed.

Those files are ancestors of `4e5fa663414b317f9bdfc05ccd7735bb07a71e90`. The full package suites that include them passed: core 194, persistence 42.

The Grok agent itself returned HOLD. It did not later return PASS. The attack tests it wrote pass on the integrated SHA after the orchestrator fix.

## Attacks covered by those tests

- empty history is not KnownScore(0–0)
- empty integrity evidence blocks KnownScore
- one capture intent cannot become two Goals, including across two `MainRefereeScope` instances
- same intent rebound to another team is a conflict
- supersession reversal when the restoring id sorts first keeps the original Goal id
- correction cycle is not a numeral
- record-order permutation keeps one KnownScore
- origin sequences 1 and 3 with 2 missing yield ScoreUnavailable
- `ScoreUnavailable` and `ScoreConflicted` have no legacy home/away integer
- two store connections cannot persist two Goals for one capture intent

Later orchestrator tests, not written by the saboteur, cover a failed score refresh leaving the Goal row in place, and denial when the generation-1 root is missing or does not match the capture identity.
