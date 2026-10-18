# FORREF — WAVE 1 GOAL + SCORE HANDOFF

STATUS: PASS

FOUNDATION SHA: `5772671a9674e00c372268047d5f54073610af22`

EXECUTION BASE SHA: `54d4de0215de208c7fea1d30cbbbeb9535f81efd`

IMPLEMENTATION TIP: `4e5fa663414b317f9bdfc05ccd7735bb07a71e90`

BRANCH: `cursor/forref-wave1-goal-score-30fd`

ANCESTRY: PASS. `5772671a9674e00c372268047d5f54073610af22` is an ancestor of the implementation tip.

## SHA chain

| SHA | Role |
| --- | --- |
| `5772671a9674e00c372268047d5f54073610af22` | Accepted Foundation Freeze |
| `54d4de0215de208c7fea1d30cbbbeb9535f81efd` | Execution base. Documentation status only |
| `1ac83408f837e4c45464fc6d8a316b6074e29dd6` | Stage 1 Goal and score projection |
| `33682524e8df60b9128cc49bd754067c411c3af6` | Order-independent supersession; integrity evidence required |
| `08439b55affbd3ed906444d4f48ffed0c4009c95` | Correction cycles fail closed |
| `8d1e49ce5dc8f965e8746d04b1254f194d4fc8f9` | Stage 2 durable capture-intent admission |
| `139f40fc49b3adf22f25222d366407fbed1c8449` | Stage 3 MATCH_MEMORY Goal cutover |
| `a1ae8f98e676417590611691d0e121b1cc68ad25` | Record-id integrity binding; list score hides unproven numerals |
| `183749e4db519ae151efd8f39c865690821aa5a1` | Saboteur attack tests |
| `488289d94c7e48120ade102f1dabfe0d1e125131` | Integrity-attack fixture period identity |
| `d31f1d1e7459649e62d01b73a42cb2f74d8e51a7` | `MainRefereeScope` value equality; generation other than 1 denied |
| `acb0702cc78c43780ca3ed778b0b6a16b99e0df6` | Failed score refresh clears the numeral |
| `4e5fa663414b317f9bdfc05ccd7735bb07a71e90` | Generation-1 root eligibility tests |

## Implemented

- `MatchTeamId` is an opaque non-empty string. `HOME` and `AWAY` are rejected.
- GOAL v1 is `HUMAN_DETERMINATION` under `MAIN_REFEREE`, with `scoringTeamId` and `captureIntentId`.
- Capture-intent identity is `(matchId, MAIN_REFEREE, captureIntentId)` bound to semantic, principal, generation, and scoring team.
- Effective Goals use existing correction and legal-supersession links, including reversal, cycles, missing targets, and competing corrections.
- `ScoreProjection` is `KnownScore`, `ScoreUnavailable`, or `ScoreConflicted`. Numerals exist only on `KnownScore`.
- Known 0–0 requires the generation-1 completeness proof, including zero effective Goals.
- SQLite admits the capture intent and the Goal record in one transaction. `journal_mode=DELETE` and `synchronous=FULL` are unchanged.
- Generation-1 root is explicit. A later open does not recreate a missing root. Phone Goal commit refuses generation other than 1, a missing root after records exist, and a principal or device that does not match the root.
- MATCH_MEMORY Goal does not call the legacy Goal writer. A failed commit does not fall back to it.
- Phone score reads `ScoreProjection`. Unavailable and conflicted omit the numeral. A thrown refresh replaces a previous numeral with `ScoreUnavailable`.

## Not implemented

Yellow, cautions recall, red, second-caution dismissal, substitution, injury, participant registry, own-goal enrichment, scorer identity, watch clients, authority transfer, generation 2, replication, billing, and visual redesign.

## Historical reuse

| SHA | Class |
| --- | --- |
| `3c2a37dada8560765c45597975b67edd8d422448` PR #2 | PARTIAL REUSE. Concept only. `scoringSide` and empty `homeScore=0` / `awayScore=0` rejected. |
| `4e602485c2a9bb85754b7cdb060ac16ac1318aed` PR #3 | PARTIAL REUSE. Phone-boundary idea only. Not merged. |
| `3c07f1a09d4cd6272acc04acd8113fccfff736ff` PR #4 | REJECT. Integer 0–0 empty projection. |

## Gates

| Gate | Result |
| --- | --- |
| ONE WRITABLE AUTHORITY | PASS |
| GOAL D1 | PASS |
| CAPTURE INTENT IDEMPOTENCY | PASS |
| GENERATION-1 AUTHORITY ROOT | PASS |
| GOAL CORRECTION / SUPERSESSION | PASS |
| SCORE PROJECTION | PASS |
| KNOWN 0–0 PROOF | PASS |
| LEGACY GOAL CUTOVER | PASS |
| LEGACY SCORE FALLBACK | ABSENT |
| INTEGRITY | PASS |
| TEST MATRIX | 24/24 software PASS. Physical power loss remains LOCAL GATE REQUIRED on rows 01 and 20. |
| SABOTEUR | Agent returned HOLD. Attack tests pass after `d31f1d1`. See [WAVE1_ADVERSARIAL_REPORT.md](WAVE1_ADVERSARIAL_REPORT.md). |
| FOUNDATION DELTAS | NONE |
| PRODUCT UX DELTAS | NONE. Unavailable and conflicted scores omit the numeral. The capture overlay still asks for a player; `commitGoal` does not require that player. |
| ARCHITECTURE INVARIANTS | PASS |
| WAVE 2 | HOLD. Not authorized. |

## Local gates

LOCAL GATE REQUIRED. HARDWARE EVIDENCE ABSENT. HUMAN EVIDENCE ABSENT.

Still open: physical D1 power-loss, real-device storage, platform restart, watch lifecycle, battery, physical watch, human referee validation.

## Repository verification

Command, from repository root, on implementation tip `4e5fa663414b317f9bdfc05ccd7735bb07a71e90`:

`./tool/verify_cloud.sh`

Result: PASSED. Exit 0. TEST EXECUTED PASS. Not CI PASS. Not physical certification.

- cloud bootstrap PASS
- analyze and test `packages/forref_match_core`: 194 passed
- analyze and test `packages/forref_match_persistence`: 42 passed
- analyze and test `apps/referee_phone`: 125 passed

The documentation commit that records this result does not change production code. The production tree it records is `4e5fa663414b317f9bdfc05ccd7735bb07a71e90`.
