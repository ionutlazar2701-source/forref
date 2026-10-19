# FORREF — WAVE 1-R REMEDIATION

STATUS: PASS

FOUNDATION SHA: `5772671a9674e00c372268047d5f54073610af22`

PRE-REMEDIATION PRODUCTION SHA: `4e5fa663414b317f9bdfc05ccd7735bb07a71e90`

REMEDIATION BASE SHA: `8cf72166a0d4c2173df4f4c6c90b8e99fc20b29c`

RESULT PRODUCTION SHA: `fa4a7976e153e7a0096aaad2958116a3a97f5bc1`

BRANCH: `cursor/forref-wave1-r-remediation-30fd`

The documentation commit that records this file does not change production code. Production libraries at the later test-only commit `49dbfb73f26447bf4ed897062815d95d116cd612` match `fa4a7976e153e7a0096aaad2958116a3a97f5bc1`.

Historical commits were not rewritten. The earlier WAVE 1 evidence at `8cf72166a0d4c2173df4f4c6c90b8e99fc20b29c` remains evidence of `4e5fa663414b317f9bdfc05ccd7735bb07a71e90`.

## SHA chain on this branch

| SHA | Role |
| --- | --- |
| `8cf72166a0d4c2173df4f4c6c90b8e99fc20b29c` | Remediation base. Earlier WAVE 1 evidence |
| `eeede83` | Cherry-pick of test-only probes `1c8ed91c95fdb4b47e769b1a61b9b4ba57f74217` |
| `fa4a7976e153e7a0096aaad2958116a3a97f5bc1` | Production repair |
| `49dbfb73f26447bf4ed897062815d95d116cd612` | Independent saboteur attacks, tests only |

## R1 origin completeness

PASS.

`validateScoreCompletenessProof` groups committed sequences by `originDeviceId`. Every observed origin must be the generation-1 root device, and that origin's sequences must form a contiguous frontier. Any other origin, and any missing sequence on the root origin, returns `ScoreUnavailable`.

A complete contiguous root-only history can still be `KnownScore`, including Known 0–0.

WAVE 1 has no authority-transfer record. A foreign origin is unexplained and fails closed. No second completeness engine was added.

## R2 generation-1 enforcement

PASS.

Write admission: `_rejectNewGoalAdmission` runs for a new Goal before a capture-intent row is inserted. It requires generation 1, an existing generation-1 root, a principal that matches that root, and an origin device that matches that root. Failure is `DurableCommitFailure` after `ROLLBACK`. No Goal row. No capture-intent admission. A same-command retry of an already admitted Goal still returns that record. Non-Goal records are outside this gate.

Read and projection: a `GoalPayload` whose authority generation is not 1 makes `validateScoreCompletenessProof` return unavailable. The projector does not tally that Goal into `KnownScore`.

`MatchApplicationBoundary.commitGoal` still denies generation other than 1.

## R3 correction and supersession

PASS.

The frozen typed contract requires correction and legal supersession to compose, and it does not define a deterministic sporting meaning for legal supersession of a correction. The generic resolver therefore returns `EffectiveGoalUnavailable` when an effective legal supersession targets a record whose kind is correction and whose payload is `CorrectionPayload`. The projector maps that to `ScoreUnavailable`.

An unsuperseded correction still applies `repairedScoringTeamId`. Direct supersession of a Goal still removes that Goal. Supersession of that supersession restores the same Goal. When the supersession of a correction is itself superseded, the correction applies again. Missing targets, cycles, competing branches, and arrival-order independence remain on the same resolver.

## Pre-fix reproduction

On the cherry-picked probes, before `fa4a7976e153e7a0096aaad2958116a3a97f5bc1`:

```
cd packages/forref_match_core && dart test test/adversarial/wave1_sr_saboteur_probe_test.dart
```

0 passed, 3 failed, exit 1. TEST EXECUTED FAIL — EXPECTED REPRODUCTION.

- foreign sequences 1 and 3: actual `KnownScore(team-alpha=0,team-beta=0)`
- generation-2 Goal: actual `KnownScore(team-alpha=1,team-beta=0)`
- superseded correction: actual `KnownScore(team-alpha=0,team-beta=1)`

```
cd packages/forref_match_persistence && dart test test/wave1_sr_saboteur_probe_test.dart
```

0 passed, 2 failed, exit 1. TEST EXECUTED FAIL — EXPECTED REPRODUCTION.

- generation-2 commit: actual `DurableCommitSuccess`, `goalIds=[goal-gen2]`, `KnownScore(team-alpha=1,team-beta=0)`
- stored foreign gap: actual `KnownScore(team-alpha=0,team-beta=0)`

## Post-fix targeted tests

On `fa4a7976e153e7a0096aaad2958116a3a97f5bc1`:

```
cd packages/forref_match_core && dart test \
  test/adversarial/wave1_goal_saboteur_test.dart \
  test/adversarial/wave1_sr_saboteur_probe_test.dart \
  test/goal_score_projection_test.dart
```

28 passed, exit 0. TEST EXECUTED PASS.

```
cd packages/forref_match_persistence && dart test \
  test/wave1_goal_saboteur_test.dart \
  test/wave1_sr_saboteur_probe_test.dart \
  test/goal_capture_intent_admission_test.dart \
  test/sqlite_durable_match_store_test.dart
```

26 passed, exit 0. TEST EXECUTED PASS.

Full package suites on the same production tree: core 199 passed, exit 0; persistence 44 passed, exit 0. Phone `flutter test test/goal_cutover_test.dart`: 9 passed, exit 0.

After `49dbfb73f26447bf4ed897062815d95d116cd612`, the new attack files plus the WAVE 1-SR probes: core 20 passed, exit 0; persistence 10 passed, exit 0.

## Wave 1 test matrix

24/24 software PASS against `fa4a7976e153e7a0096aaad2958116a3a97f5bc1`. Rows 01 and 20 remain LOCAL GATE REQUIRED for real power loss. Detail: [WAVE1_TEST_MATRIX.md](WAVE1_TEST_MATRIX.md).

## Repository verification

Command, from repository root, on production SHA `fa4a7976e153e7a0096aaad2958116a3a97f5bc1`:

`./tool/verify_cloud.sh`

PASSED. Exit 0. TEST EXECUTED PASS. Not CI PASS. Not physical certification.

- cloud bootstrap PASS
- analyze and test `packages/forref_match_core`: 199 passed
- analyze and test `packages/forref_match_persistence`: 44 passed
- analyze and test `apps/referee_phone`: 125 passed

## Independent saboteur

PASS.

Review id: `bc-c6f50068-a8c3-5abe-a12b-e6d85562070d`.

Reviewed SHA: `fa4a7976e153e7a0096aaad2958116a3a97f5bc1`.

Verdict: SABOTEUR PASS. The reviewer re-attacked R1, R2, R3, and `MainRefereeScope`, and did not edit production code. Detail: [WAVE1_ADVERSARIAL_REPORT.md](WAVE1_ADVERSARIAL_REPORT.md).

## Production code

- `packages/forref_match_core/lib/projection/score_completeness_proof.dart`
- `packages/forref_match_core/lib/projection/effective_goal_resolver.dart`
- `packages/forref_match_persistence/lib/sqlite_durable_match_store.dart`

`deterministic_match_projector.dart` already mapped `EffectiveGoalUnavailable` to `ScoreUnavailable`. Phone UI was not changed. SQLite `journal_mode=DELETE` and `synchronous=FULL` are unchanged.

## Gates

| Gate | Result |
| --- | --- |
| FOUNDATION DELTAS | NONE |
| PRODUCT UX DELTAS | NONE |
| LOCAL GATES | Unchanged. Physical D1 power-loss, real-device storage, platform restart, watch lifecycle, battery, physical watch, human referee validation. LOCAL GATE REQUIRED. HARDWARE EVIDENCE ABSENT. HUMAN EVIDENCE ABSENT. |
| WAVE 1 | CANDIDATE PASS |
| WAVE 2 | HOLD — NOT AUTHORIZED |

## Recommendation

Cele trei găuri de probă sunt închise pe `fa4a7976e153e7a0096aaad2958116a3a97f5bc1`: originea străină incompletă sau neexplicată nu mai produce scor cunoscut, golul de generație 2 nu se admite și nu intră în scor, iar corecția superscrisă nu mai lasă numeralul reparat. Sabotorul independent a emis SABOTEUR PASS. Porțile fizice și umane rămân deschise. WAVE 2 nu pornește.
