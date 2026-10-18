# WAVE 1 test matrix

Implementation tip these rows describe: `4e5fa663414b317f9bdfc05ccd7735bb07a71e90`.

Labels mean local execution. None of these rows is CI PASS. None is physical certification.

| # | Obligation | Evidence | Label |
| --- | --- | --- | --- |
| 01 | Crash before, during, and after D1 commit | `goal_capture_intent_admission_test.dart`: `abortBeforeCommitForTest rolls back record and capture intent`; `after DurableCommitSuccess close reopen keeps record and intent`. Software abort before `COMMIT`. | TEST EXECUTED PASS. Real sudden power loss: LOCAL GATE REQUIRED. |
| 02 | Ambiguous ACK recovery | Same file: reopen after success, then `same capture intent retry returns original record id without second row`. | TEST EXECUTED PASS. Software reopen, not a physical crash. |
| 03 | Same-intent retry | Persistence retry test above. Core: `idempotent same intent vs conflict on different team` in `goal_score_projection_test.dart`. | TEST EXECUTED PASS. |
| 04 | Concurrent duplicate capture | `concurrent duplicate intent commits end with one admission row`. Saboteur: `concurrent store connections cannot persist two goals for one capture intent`. | TEST EXECUTED PASS. |
| 05 | Conflicting intent payload | Core and persistence: same intent with a different scoring team does not append. Saboteur: separately constructed `MainRefereeScope` values still conflict. | TEST EXECUTED PASS. |
| 06 | Empty database cannot yield KnownScore(0–0) | `empty history is ScoreUnavailable`. Saboteur: `empty record list is not KnownScore 0-0`, including when a proof object is supplied. | TEST EXECUTED PASS. |
| 07 | Valid complete bootstrap yields KnownScore(0–0) | `valid proof with zero effective goals is KnownScore 0-0`. Phone: `kick-off with bound integrity and no goals is KnownScore 0-0`. | TEST EXECUTED PASS. |
| 08 | Missing origin sequence yields ScoreUnavailable | Saboteur: `missing origin sequence 2 yields ScoreUnavailable`. | TEST EXECUTED PASS. |
| 09 | Unsupported potentially score-affecting semantic yields ScoreUnavailable | `score_trust_fail_closed_test.dart`: non-goal v1 codes leave score untrusted and expose no numeral. Completeness proof rejects `unsupportedSemanticRecordIds`. | TEST EXECUTED PASS. |
| 10 | Correction with missing target | `missing correction target yields unavailable score`. | TEST EXECUTED PASS. |
| 11 | Competing corrections | `competing corrections yield conflicted score`. | TEST EXECUTED PASS. |
| 12 | Goal legal supersession removes scoring effect | `supersession removes goal; reversal restores same goal id`. | TEST EXECUTED PASS. |
| 13 | Supersession reversal restores the same Goal without a duplicate | Same test, plus `supersession reversal restores goal when restore record id sorts before void`. Saboteur: `supersession reversal counts the original goal id when the restoring record id sorts first`. | TEST EXECUTED PASS. |
| 14 | Cycle detection | `cycle yields unavailable score, not a numeral`. `correction cycle yields unavailable score`. Saboteur: `a correction cycle does not yield a numeral`. | TEST EXECUTED PASS. |
| 15 | Transport/record-arrival permutation equivalence | `permuting record order does not change effective goals`. Saboteur: `permuting record order does not change KnownScore`. | TEST EXECUTED PASS. |
| 16 | Integrity mismatch | `empty integrity evidence on any record forces ScoreUnavailable`. Saboteur rejects a caller proof when any record has empty evidence. `corrupt json row remains and quarantine is reported on read`. | TEST EXECUTED PASS. |
| 17 | Duplicate recordId with different canonical content | `sqlite_durable_match_store_test.dart`: `same recordId with different content fails closed`. | TEST EXECUTED PASS. |
| 18 | Duplicate origin slot with different content | `origin-sequence conflict fails closed`. | TEST EXECUTED PASS. |
| 19 | Corrupt or missing generation-1 authority root | Store: `missing generation-1 root is not recreated when records exist`; `second generation-1 root with different principal fails`. Phone: `Goal is denied when records exist without a generation-1 root`; `Goal is denied when capture identity does not match the generation-1 root`. | TEST EXECUTED PASS. |
| 20 | MATCH READY followed by storage failure | `abortBeforeCommitForTest` rolls the record and the capture intent back. MATCH READY is derived admission, not a stored write permission. | TEST EXECUTED PASS for the software storage failure. Real power loss: LOCAL GATE REQUIRED. |
| 21 | Stale or unqualified capture authority denies Goal | `generation other than 1 cannot commit a Goal`. Mismatched generation-1 principal or device is denied. A second generation-1 root with a different principal fails. | TEST EXECUTED PASS. |
| 22 | Goal D1 succeeds while ScoreProjection refresh fails | `saved Goal stays saved when score refresh cannot be proven`: the Goal row remains, `readScoreProjection` returns `ScoreUnavailable`, and the legacy event list gains no goal. Live Match clears `_scoreProjection` to `ScoreUnavailable` when the refresh throws. | TEST EXECUTED PASS. |
| 23 | Temporal degradation does not remove an otherwise proven Goal or score | `temporal context absent still allows goal to count with proof`. | TEST EXECUTED PASS. |
| 24 | Legacy plus MATCH_MEMORY mixed-authority Goal write is rejected | `MATCH_MEMORY goal commit does not add a legacy goal event`. `failed D1 goal commit does not add a legacy goal event`. Match list and live score omit legacy numerals while Match Memory is attached. | TEST EXECUTED PASS. |

Package counts recorded before the documentation commit, on the production tree through `d31f1d1e7459649e62d01b73a42cb2f74d8e51a7` for core and persistence, and on `4e5fa663414b317f9bdfc05ccd7735bb07a71e90` for the phone Goal cutover file:

- `cd packages/forref_match_core && dart test` — 194 passed, exit 0. TEST EXECUTED PASS.
- `cd packages/forref_match_persistence && dart test` — 42 passed, exit 0. TEST EXECUTED PASS.
- `cd apps/referee_phone && flutter test test/goal_cutover_test.dart` — 9 passed after the generation-1 eligibility tests, exit 0. TEST EXECUTED PASS.

`./tool/verify_cloud.sh` on `4e5fa663414b317f9bdfc05ccd7735bb07a71e90`: PASSED. Exit 0. Core 194, persistence 42, phone 125. TEST EXECUTED PASS. Not CI PASS.
