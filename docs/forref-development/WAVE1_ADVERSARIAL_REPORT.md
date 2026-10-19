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

## WAVE 1-SR

Independent re-review: Grok. Run `bc-d24753e2-94b9-55d2-a9ae-885aea2f9f12`.

Reviewed production tip: `4e5fa663414b317f9bdfc05ccd7735bb07a71e90`. Evidence tip: `8cf72166a0d4c2173df4f4c6c90b8e99fc20b29c`.

SABOTEUR HOLD.

`MainRefereeScope` value equality from `d31f1d1e7459649e62d01b73a42cb2f74d8e51a7` held. Original suites on that tip: core saboteur 11 passed, persistence saboteur 3 passed.

Three new defects, reproduced by test-only probes `20eabf91917331054b187d0f4caa33a4e1d0ac1c` (parent `4e5fa66`) and `1c8ed91c95fdb4b47e769b1a61b9b4ba57f74217` (parent `8cf72166`):

- R1. Completeness built a sequence frontier only for the generation-1 root device. A foreign origin with sequences 1 and 3, missing 2, became `KnownScore(team-alpha=0,team-beta=0)`.
- R2. `commitGoal` rejected generation other than 1. The durable store still admitted a generation-2 Goal, and the projector counted it as `KnownScore(team-alpha=1,team-beta=0)`.
- R3. An effective legal supersession of the correction that repaired a Goal to team-beta still produced `KnownScore(team-alpha=0,team-beta=1)`.

Pre-fix execution on the cherry-picked probes, before `fa4a7976e153e7a0096aaad2958116a3a97f5bc1`:

- `cd packages/forref_match_core && dart test test/adversarial/wave1_sr_saboteur_probe_test.dart` — 0 passed, 3 failed, exit 1. TEST EXECUTED FAIL — EXPECTED REPRODUCTION.
- `cd packages/forref_match_persistence && dart test test/wave1_sr_saboteur_probe_test.dart` — 0 passed, 2 failed, exit 1. TEST EXECUTED FAIL — EXPECTED REPRODUCTION.

The reviewer did not edit production code.

## WAVE 1-R independent saboteur

Independent post-fix review: Grok. Run `bc-c6f50068-a8c3-5abe-a12b-e6d85562070d`.

Reviewed production SHA: `fa4a7976e153e7a0096aaad2958116a3a97f5bc1`.

SABOTEUR PASS.

The reviewer added tests only. It did not edit `lib/`. Those tests are `49dbfb73f26447bf4ed897062815d95d116cd612` on `cursor/forref-wave1-r-remediation-30fd`. Production libraries at that commit match `fa4a7976e153e7a0096aaad2958116a3a97f5bc1`.

Re-attacks that held:

- R1. Root gaps, a history that starts at sequence 2, duplicate sequences with a later hole, a contiguous unauthorized foreign origin, and a foreign-only history are `ScoreUnavailable`. A complete contiguous root history can still be `KnownScore`.
- R2. A new generation-2 Goal is `DurableCommitFailure` through `commit` and `commitAtNextOriginSequence`. No Goal row and no capture-intent admission. A raw stored generation-2 Goal, a null generation, and a duplicate record id carrying generation 2 are `ScoreUnavailable`. A same-command generation-1 retry still returns the existing record.
- R3. An effective legal supersession of a Goal correction is `ScoreUnavailable` for every arrival order and after a SQLite round trip. Reversal of that supersession restores `KnownScore` for the repaired team. Direct Goal supersession removes the Goal. Reversal restores that Goal. An unsuperseded correction still applies the repaired team.
- `MainRefereeScope` value equality still binds one capture intent to one Goal in memory and in SQLite. A different scoring team remains a conflict with one row.

Suites the reviewer ran on `fa4a7976e153e7a0096aaad2958116a3a97f5bc1`: core targeted files 28 passed, exit 0; persistence targeted files 15 passed, exit 0.

Orchestrator re-run after cherry-picking the reviewer's attacks onto the remediation branch: core `wave1_r_saboteur_attack_test.dart` plus `wave1_sr_saboteur_probe_test.dart` — 20 passed, exit 0; persistence equivalents — 10 passed, exit 0.

Residual note from the reviewer, recorded and not a HOLD: a hand-built `projectRecords` list that mixes a Goal from another `matchId` can be tallied because `resolveEffectiveGoals` does not filter `matchId`, while the completeness proof does. `commit` writes the column and the JSON `matchId` from the same field, and `readCommittedForMatch` does not return that mixed list. Same-match generation 2 fails closed. No production change was made for that note.
