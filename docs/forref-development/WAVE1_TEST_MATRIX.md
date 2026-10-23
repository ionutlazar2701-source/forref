# WAVE 1 test matrix

Production behavior these rows describe: `fa4a7976e153e7a0096aaad2958116a3a97f5bc1`.

The earlier matrix on `4e5fa663414b317f9bdfc05ccd7735bb07a71e90` remains evidence of that candidate. WAVE 1-SR held that candidate. This file is the re-evaluation after WAVE 1-R.

Labels mean local execution. None of these rows is CI PASS. None is physical certification.

| # | Obligation | Evidence | Label |
| --- | --- | --- | --- |
| 01 | Crash before, during, and after D1 commit | `goal_capture_intent_admission_test.dart`: `abortBeforeCommitForTest rolls back record and capture intent`; `after DurableCommitSuccess close reopen keeps record and intent`. Software abort before `COMMIT`. | TEST EXECUTED PASS. Real sudden power loss: LOCAL GATE REQUIRED. |
| 02 | Ambiguous ACK recovery | Same file: reopen after success, then `same capture intent retry returns original record id without second row`. | TEST EXECUTED PASS. Software reopen, not a physical crash. |
| 03 | Same-intent retry | Persistence retry test above. Core: `idempotent same intent vs conflict on different team` in `goal_score_projection_test.dart`. | TEST EXECUTED PASS. |
| 04 | Concurrent duplicate capture | `concurrent duplicate intent commits end with one admission row`. Saboteur: `concurrent store connections cannot persist two goals for one capture intent`. | TEST EXECUTED PASS. |
| 05 | Conflicting intent payload | Core and persistence: same intent with a different scoring team does not append. Saboteur: separately constructed `MainRefereeScope` values still conflict. | TEST EXECUTED PASS. |
| 06 | Empty database cannot yield KnownScore(0–0) | `empty history is ScoreUnavailable`. Saboteur: `empty record list is not KnownScore 0-0`, including when a proof object is supplied. | TEST EXECUTED PASS. |
| 07 | Valid complete bootstrap yields KnownScore(0–0) | `valid proof with zero effective goals is KnownScore 0-0`. Phone: `kick-off with bound integrity and no goals is KnownScore 0-0`. Probe: `a complete root-only history can still be KnownScore 0-0`. | TEST EXECUTED PASS. |
| 08 | Missing origin sequence yields ScoreUnavailable | Root gap: `missing origin sequence 2 yields ScoreUnavailable`. Foreign origin sequences 1 and 3 with 2 missing: `a sequence gap on a non-root origin does not yield KnownScore 0-0` and the stored persistence probe. Result is `ScoreUnavailable`. | TEST EXECUTED PASS. |
| 09 | Unsupported potentially score-affecting semantic yields ScoreUnavailable | `score_trust_fail_closed_test.dart`: non-goal v1 codes leave score untrusted and expose no numeral. Completeness proof rejects `unsupportedSemanticRecordIds`. | TEST EXECUTED PASS. |
| 10 | Correction with missing target | `missing correction target yields unavailable score`. | TEST EXECUTED PASS. |
| 11 | Competing corrections | `competing corrections yield conflicted score`. | TEST EXECUTED PASS. |
| 12 | Goal legal supersession removes scoring effect | Direct Goal supersession: `supersession removes goal; reversal restores same goal id`. An effective legal supersession of a Goal `CorrectionPayload` yields `ScoreUnavailable`. It does not leave `KnownScore` for the repaired team. | TEST EXECUTED PASS. |
| 13 | Supersession reversal restores the same Goal without a duplicate | Same direct-Goal test, plus `supersession reversal restores goal when restore record id sorts before void`. Saboteur: `supersession reversal counts the original goal id when the restoring record id sorts first`. Reversal of a supersession that targeted a correction makes that correction effective again. | TEST EXECUTED PASS. |
| 14 | Cycle detection | `cycle yields unavailable score, not a numeral`. `correction cycle yields unavailable score`. Saboteur: `a correction cycle does not yield a numeral`. | TEST EXECUTED PASS. |
| 15 | Transport/record-arrival permutation equivalence | `permuting record order does not change effective goals`. Saboteur: `permuting record order does not change KnownScore`. Every arrival order of a superseded Goal correction stays `ScoreUnavailable`. | TEST EXECUTED PASS. |
| 16 | Integrity mismatch | `empty integrity evidence on any record forces ScoreUnavailable`. Saboteur rejects a caller proof when any record has empty evidence. `corrupt json row remains and quarantine is reported on read`. | TEST EXECUTED PASS. |
| 17 | Duplicate recordId with different canonical content | `sqlite_durable_match_store_test.dart`: `same recordId with different content fails closed`. | TEST EXECUTED PASS. |
| 18 | Duplicate origin slot with different content | `origin-sequence conflict fails closed`. A contiguous foreign origin beside a complete root history is `ScoreUnavailable`. | TEST EXECUTED PASS. |
| 19 | Corrupt or missing generation-1 authority root | Store: `missing generation-1 root is not recreated when records exist`; a later Goal commit fails and stores no Goal row. `second generation-1 root with different principal fails`. Phone: `Goal is denied when records exist without a generation-1 root`; `Goal is denied when capture identity does not match the generation-1 root`. | TEST EXECUTED PASS. |
| 20 | MATCH READY followed by storage failure | `abortBeforeCommitForTest` rolls the record and the capture intent back. MATCH READY is derived admission, not a stored write permission. | TEST EXECUTED PASS for the software storage failure. Real power loss: LOCAL GATE REQUIRED. |
| 21 | Stale or unqualified capture authority denies Goal | Phone `commitGoal` still denies generation other than 1. Durable Goal admission denies generation other than 1, a missing root, a mismatched principal, and a mismatched origin device, with no Goal row and no capture-intent admission. Projection of a Goal whose generation is not 1 is `ScoreUnavailable`. | TEST EXECUTED PASS. |
| 22 | Goal D1 succeeds while ScoreProjection refresh fails | `saved Goal stays saved when score refresh cannot be proven`: the Goal row remains, `readScoreProjection` returns `ScoreUnavailable`, and the legacy event list gains no goal. Live Match clears `_scoreProjection` to `ScoreUnavailable` when the refresh throws. | TEST EXECUTED PASS. |
| 23 | Temporal degradation does not remove an otherwise proven Goal or score | `temporal context absent still allows goal to count with proof`. | TEST EXECUTED PASS. |
| 24 | Legacy plus MATCH_MEMORY mixed-authority Goal write is rejected | `MATCH_MEMORY goal commit does not add a legacy goal event`. `failed D1 goal commit does not add a legacy goal event`. Match list and live score omit legacy numerals while Match Memory is attached. An unexplained foreign origin fails closed as `ScoreUnavailable`. | TEST EXECUTED PASS. |

Re-scored result: 24/24 software PASS on `fa4a7976e153e7a0096aaad2958116a3a97f5bc1`. Rows 01 and 20 remain LOCAL GATE REQUIRED for real power loss.

Package counts on that production tree, before the later test-only saboteur commit `49dbfb73f26447bf4ed897062815d95d116cd612`:

- `cd packages/forref_match_core && dart test` — 199 passed, exit 0. TEST EXECUTED PASS.
- `cd packages/forref_match_persistence && dart test` — 44 passed, exit 0. TEST EXECUTED PASS.
- `cd apps/referee_phone && flutter test test/goal_cutover_test.dart` — 9 passed, exit 0. TEST EXECUTED PASS.

Targeted suites on the same production tree:

- core `wave1_goal_saboteur_test.dart`, `wave1_sr_saboteur_probe_test.dart`, `goal_score_projection_test.dart` — 28 passed, exit 0.
- persistence `wave1_goal_saboteur_test.dart`, `wave1_sr_saboteur_probe_test.dart`, `goal_capture_intent_admission_test.dart`, `sqlite_durable_match_store_test.dart` — 26 passed, exit 0.

`./tool/verify_cloud.sh` on `fa4a7976e153e7a0096aaad2958116a3a97f5bc1`: PASSED. Exit 0. Core 199, persistence 44, phone 125. TEST EXECUTED PASS. Not CI PASS.

The earlier `./tool/verify_cloud.sh` result on `4e5fa663414b317f9bdfc05ccd7735bb07a71e90` (core 194, persistence 42, phone 125, exit 0) remains evidence of that candidate. It does not certify this repair.
