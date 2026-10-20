# Program ledger

Status of this file: RECORD

Canonical contract: [FOUNDATION_FREEZE.md](FOUNDATION_FREEZE.md)

DOMAIN: FROZEN

ARCHITECTURE: FROZEN CANDIDATE

RELIABILITY: FROZEN CANDIDATE

SIMPLICITY: FROZEN CANDIDATE

PRODUCT COMMAND: FOUNDATION FREEZE ACCEPTED

WAVE 1: ACCEPTED / CLOSED at production `fa4a7976e153e7a0096aaad2958116a3a97f5bc1`, evidence `6ec364cee2af78dc3f2f3d2c4110b95f4660f780`.

WAVE 2+: Night program Phase I is PARTIAL. See [night-program/MORNING_HANDOFF.md](night-program/MORNING_HANDOFF.md). Phase II finished the remaining banks and the two disciplinary bridges. See [night-program/PHASE2_HANDOFF.md](night-program/PHASE2_HANDOFF.md). Phone authority cutover stays HOLD.

Accepted Foundation SHA: `5772671a9674e00c372268047d5f54073610af22`.

The older branch `cursor/forref-wave1-integration-30fd` is a previous test and harness wave. It is not V2 WAVE 1. V2 WAVE 1 is Goal and Score under [WAVE1_GOAL_SCORE_CONTRACT.md](WAVE1_GOAL_SCORE_CONTRACT.md). The repaired candidate is `cursor/forref-wave1-r-remediation-30fd`. WAVE 2 is not authorized.

Specialist authority results below are the WAVE 0D inputs. They are not Product Command acceptance. Don and Tony hardware/human certification were not issued. LOCAL GATE REQUIRED remains for physical proof.

## WAVE 0

| Field | Value |
| --- | --- |
| STATUS | HOLD |
| PARENT SHA | `32eded4e8d18fa0165bb170209afe9b3b0ee5e29` |
| EXECUTION SHA | Contract pack `c157f14620160549cd4e4634935c4a9bfc3ecd2f`. 002D correction `35c10a20016d9955eee92f84f911ebd2c5a85374`. The tip that records this test line is the branch execution tip; read it with `git rev-parse HEAD` after that commit. |
| BRANCH | `cursor/forref-wave0-contract-freeze-30fd` |
| SUBAGENT | FORREF WAVE 0 domain/architecture reviewer. Requested model: grok-4.7-high. Actual model: Grok 4.7. |
| OWNED FILES | `docs/forref-development/**`. Surgical factual corrections in `docs/forref-execution/` only where a missing-SHA claim for `fda5af6` or `research/watch_core_r1` was stated: `RESEARCH_TO_REPO_AUDIT.md`, `RISK_REGISTER.md`, `NEXT_WAVE.md`, `DEPENDENCY_GRAPH.md`, `WAVE_EXECUTION_PLAN.md`, `HANDOFF_RO.md`. |
| TESTS | `cd packages/forref_match_core && dart test` at `c157f14620160549cd4e4634935c4a9bfc3ecd2f`. 170 passed. Exit code 0. TEST EXECUTED PASS. That label does not authorize domain semantics. |
| ADVERSARIAL RESULT | HOLD. Governance contradiction recorded and not applied. Domain contracts are drafts. Two goal forks conflict with each other and their integer `0–0` empty score conflicts with the score hard rule. Legacy injury, red, and substitution writers remain on the phone cutover line. No sporting-law invention. No authority PASS. |
| HOLDS | Founder scope. Match Authority freeze. Visual design. Injury decision. Goal payload choice. Score known-zero predicate. Cautions "No" predicate. Enter-field semantic from PR #9. PR #9 store serializer. |
| LOCAL GATES | LOCAL GATE REQUIRED. PHYSICAL DATA REQUIRED. HARDWARE EVIDENCE ABSENT. Power-loss D1 is not certified. No device was operated. |
| AUTHORITY GATES | Founder sign-off REQUIRED and not issued. Match Authority freeze not issued. Don PASS not issued. REFEREE DATA REQUIRED. HUMAN EVIDENCE ABSENT. Tony PASS not issued. |
| NEXT WAVE | Superseded as the next action by WAVE 0D. V2 WAVE 1 stays HOLD until Product Command accepts the Foundation Freeze SHA. |

## Exclusive integration-owner files observed on the parent

Not modified. Named because later waves collide here.

Semantic registry:

- `packages/forref_match_core/lib/semantics/match_record_semantic_type.dart`
- `packages/forref_match_core/lib/semantics/v1_semantic_contract.dart`
- `packages/forref_match_core/lib/semantics/v1_semantic_payload.dart`
- `packages/forref_match_core/lib/semantics/v1_schema_semantic_interpreter.dart`
- `packages/forref_match_core/lib/semantics/schema_semantic_interpreter.dart`
- `packages/forref_match_core/lib/semantics/production_semantics_resolver.dart`
- `packages/forref_match_core/lib/semantics/production_payload_contract.dart`
- `packages/forref_match_core/lib/forref_match_core.dart`

Storage encoding:

- `packages/forref_match_persistence/lib/record_storage_encoding.dart`

The D1 adapter beside it, not edited and not a second owner, is `packages/forref_match_persistence/lib/sqlite_durable_match_store.dart`. PR #9 changes its serializer. That change is not approved.

Phone Live Match boundary:

- `apps/referee_phone/lib/features/live_match/live_match_page.dart`
- `apps/referee_phone/lib/features/live_match/capture_overlay.dart`
- `apps/referee_phone/lib/match_application/match_application_boundary.dart`
- `apps/referee_phone/lib/match_application/match_commit_port.dart`
- `apps/referee_phone/lib/match/match_session.dart`

Root package pins:

- `pubspec.yaml`
- `pubspec.lock`

Localization:

- `apps/referee_phone/l10n.yaml`
- `apps/referee_phone/lib/l10n/app_en.arb`
- `apps/referee_phone/lib/l10n/app_ro.arb`
- `apps/referee_phone/lib/l10n/app_localizations.dart`
- `apps/referee_phone/lib/l10n/app_localizations_en.dart`
- `apps/referee_phone/lib/l10n/app_localizations_ro.dart`
- `apps/referee_phone/lib/l10n/match_labels.dart`

One integration owner per wave for each of those groups. WAVE 0 changed none of them. WAVE 0D changed none of them.

## WAVE 0D

| Field | Value |
| --- | --- |
| STATUS | Consolidation candidate. Product Command acceptance pending. |
| PARENT SHA | `a15a1c2bfd3ead5fa1dd97647233c0394d1887ba` |
| EXECUTION SHA | Recorded in [WAVE0_FINAL_HANDOFF.md](WAVE0_FINAL_HANDOFF.md) after the single WAVE 0D commit. |
| BRANCH | `cursor/forref-wave0d-foundation-freeze-30fd` |
| SUBAGENTS | None. Orchestrator consolidation only. |
| OWNED FILES | `AGENTS.md` device-operating-model language. `docs/forref-development/` canonical pack and status banners. |
| TESTS | NONE in WAVE 0D. No production source changed. No CI PASS claimed. |
| ADVERSARIAL RESULT | Not a new sabotage pass. Parent diff check: production paths absent. |
| KNOWN HOLDS | WAVE 1 implementation. Yellow, Cautions, Red, Substitution, Injury, participant registry, field-entry, watch capture, authority transfer. |
| LOCAL GATES | LOCAL GATE REQUIRED for real power-loss D1, device storage, platform restart, watch lifecycle, battery, physical watch reliability, and human referee trials. Not WAVE 0D blockers. Not certified. |
| AUTHORITY GATES | Referee Domain Authority PASS. Architecture Foundation Closure PASS. Systems Simplicity Authority PASS. Mission Reliability Authority PASS. Product Command PENDING FINAL ACCEPTANCE. |
| NEXT AUTHORIZED WAVE | None. WAVE 1 is HOLD — AWAITING FOUNDATION FREEZE SHA ACCEPTANCE. |

## WAVE 0E

| Field | Value |
| --- | --- |
| STATUS | HOLD. The named active files are aligned. Unbannered contradictions remain outside the authorized file list (`README.md`, `docs/ux-live-match.md`, `docs/ux-pre-post-match.md`, `docs/forref-execution/RESEARCH_TO_REPO_AUDIT.md`, `docs/forref-execution/DEPENDENCY_GRAPH.md`). Foundation Freeze SHA `e71fa24d2d22eb63952209170ec82e1b6eb4e954` is still not accepted. |
| PARENT SHA | `e71fa24d2d22eb63952209170ec82e1b6eb4e954` |
| BRANCH | `cursor/forref-wave0e-governance-30fd` |
| TESTS | NONE. No CI PASS. |
| WAVE 1 | HOLD — awaiting Product Command acceptance. |
| CLASSIFICATION | [WAVE0E_GOVERNANCE.md](WAVE0E_GOVERNANCE.md) |

## WAVE 0F

| Field | Value |
| --- | --- |
| STATUS | Governance reconciliation candidate. Product Command PENDING FINAL ACCEPTANCE. |
| PARENT SHA | `78eba6fbbc012453f15ad123ff4298ad3b71c487` |
| BRANCH | `cursor/forref-wave0f-governance-30fd` |
| TESTS | NONE. No CI PASS. |
| WAVE 1 | HOLD — AWAITING FOUNDATION FREEZE ACCEPTANCE. |
| CLASSIFICATION | [WAVE0F_GOVERNANCE.md](WAVE0F_GOVERNANCE.md) |

## WAVE 1

| Field | Value |
| --- | --- |
| STATUS | Historical candidate. WAVE 1-SR returned SABOTEUR HOLD. Current status is WAVE 1-R below. |
| ACCEPTED FOUNDATION SHA | `5772671a9674e00c372268047d5f54073610af22` |
| EXECUTION BASE SHA | `54d4de0215de208c7fea1d30cbbbeb9535f81efd` |
| IMPLEMENTATION TIP | `4e5fa663414b317f9bdfc05ccd7735bb07a71e90` |
| EVIDENCE TIP | `8cf72166a0d4c2173df4f4c6c90b8e99fc20b29c` |
| BRANCH | `cursor/forref-wave1-goal-score-30fd` |
| SCOPE | Authoritative Goal and trustworthy score only. |
| CONTRACT | [WAVE1_GOAL_SCORE_CONTRACT.md](WAVE1_GOAL_SCORE_CONTRACT.md). Foundation semantics are unchanged. |
| EVIDENCE | [WAVE1_HANDOFF.md](WAVE1_HANDOFF.md), [WAVE1_REUSE_REPORT.md](WAVE1_REUSE_REPORT.md). The matrix and adversarial report now describe the repaired candidate. |
| TESTS | `./tool/verify_cloud.sh` on `4e5fa663414b317f9bdfc05ccd7735bb07a71e90` PASSED. Core 194, persistence 42, phone 125. TEST EXECUTED PASS. Not CI PASS. That run does not certify the repair. |
| SABOTEUR | First Grok agent returned HOLD on `MainRefereeScope` identity equality. Fixed at `d31f1d1e7459649e62d01b73a42cb2f74d8e51a7`. WAVE 1-SR `bc-d24753e2-94b9-55d2-a9ae-885aea2f9f12` confirmed that fix and returned SABOTEUR HOLD on R1, R2, and R3. |
| LOCAL GATES | LOCAL GATE REQUIRED. Physical power-loss, device storage, watch lifecycle, battery, and human referee validation remain uncertified. |
| NEXT WAVE | WAVE 2 HOLD. Identity, Yellow, and Cautions are not started. |

## WAVE 1-R

| Field | Value |
| --- | --- |
| STATUS | ACCEPTED / CLOSED. Independent post-fix saboteur issued SABOTEUR PASS. Later waves are authorized only through the night program. |
| ACCEPTED FOUNDATION SHA | `5772671a9674e00c372268047d5f54073610af22` |
| REMEDIATION BASE SHA | `8cf72166a0d4c2173df4f4c6c90b8e99fc20b29c` |
| PRE-REMEDIATION PRODUCTION SHA | `4e5fa663414b317f9bdfc05ccd7735bb07a71e90` |
| PRODUCTION SHA | `fa4a7976e153e7a0096aaad2958116a3a97f5bc1` |
| BRANCH | `cursor/forref-wave1-r-remediation-30fd` |
| SCOPE | Repair of R1 origin completeness, R2 generation-1 Goal admission and projection, and R3 superseded Goal correction. Goal and score only. |
| CONTRACT | Existing Foundation and [WAVE1_GOAL_SCORE_CONTRACT.md](WAVE1_GOAL_SCORE_CONTRACT.md). No Foundation delta. |
| EVIDENCE | [WAVE1_REMEDIATION.md](WAVE1_REMEDIATION.md), [WAVE1_TEST_MATRIX.md](WAVE1_TEST_MATRIX.md), [WAVE1_ADVERSARIAL_REPORT.md](WAVE1_ADVERSARIAL_REPORT.md) |
| TESTS | `./tool/verify_cloud.sh` on `fa4a7976e153e7a0096aaad2958116a3a97f5bc1` PASSED. Exit 0. Core 199, persistence 44, phone 125. TEST EXECUTED PASS. Not CI PASS. |
| SABOTEUR | Grok `bc-c6f50068-a8c3-5abe-a12b-e6d85562070d` reviewed `fa4a7976e153e7a0096aaad2958116a3a97f5bc1` and returned SABOTEUR PASS. Test-only attacks are `49dbfb73f26447bf4ed897062815d95d116cd612`. |
| FOUNDATION DELTAS | NONE |
| PRODUCT UX DELTAS | NONE |
| LOCAL GATES | Unchanged. LOCAL GATE REQUIRED. HARDWARE EVIDENCE ABSENT. HUMAN EVIDENCE ABSENT. |
| NEXT WAVE | Night program DAG. Identity, Yellow, and later banks are authorized only there. |

## Night program Phase II

| Field | Value |
| --- | --- |
| STATUS | PASS for the authorized banks and bridges. Phone cutover HOLD. |
| START EVIDENCE SHA | `f4bf48ffd397b1cd81cf2f40a08084aa49561b7e` |
| EXECUTION BASE SHA | `f4bf48ffd397b1cd81cf2f40a08084aa49561b7e`. Descends from `09fa0bf39bbf7b1aecaef8aa56a780b8b1249f7c`. Library diff between those SHAs is empty. |
| PRODUCTION SHA | `39a676b25682e2b6930b6d4f7f02340b55ae01a8` |
| BRANCH | `cursor/forref-night-phase2-30fd` |
| SCOPE | BANK G, BANK B2, BANK D, BANK E, status ↔ awareness, awareness ↔ SEND_OFF. |
| TESTS | `./tool/verify_cloud.sh` PASSED. Exit 0. Core 347, persistence 88, phone 125. TEST EXECUTED PASS. Not CI PASS. |
| EVIDENCE | [night-program/PHASE2_HANDOFF.md](night-program/PHASE2_HANDOFF.md), [night-program/PHASE2_ADVERSARIAL_REPORT.md](night-program/PHASE2_ADVERSARIAL_REPORT.md) |
| SABOTEUR | Grok `bc-b4ae2960-049d-5a4d-921d-b09ea16902a0`. Third review PASS. No `lib/` edits by the reviewer. |
| FOUNDATION DELTAS | NONE |
| DOMAIN DELTAS | NONE |
| PRODUCT UX DELTAS | PHONE PRODUCT / UX GATE REQUIRED |
| LOCAL GATES | Unchanged. LOCAL GATE REQUIRED. |
| NEXT WAVE | Phone product / UX authority gate. Not started. |

## Night Session III

| Field | Value |
| --- | --- |
| STATUS | PASS for the research instrument. Phone cutover HOLD. Production engineering not authorized. |
| START EVIDENCE SHA | `0c691a8b7d6f76e044ef91709150b4cede9ac6d8` |
| EXECUTION BASE SHA | `0c691a8b7d6f76e044ef91709150b4cede9ac6d8`. Descends from `39a676b25682e2b6930b6d4f7f02340b55ae01a8`. |
| PRODUCTION AUTHORITY BASELINE | `39a676b25682e2b6930b6d4f7f02340b55ae01a8`. Production authority behavior changed: NO. |
| BRANCH | `cursor/forref-night-hf-prototype-30fd` |
| SCOPE | Isolated research prototype, V2 interaction state, final-action safety, recovery evidence map, scenarios, human-validation pack. No production recovery. No phone cutover. |
| TESTS | `./tool/verify_cloud.sh` PASSED. Exit 0. Core 347, persistence 92, phone 125. Research `hf_v2` 48 passed. Research shell 8 passed. TEST EXECUTED PASS. Not CI PASS. |
| EVIDENCE | [night-session-iii/SESSION_III_HANDOFF.md](night-session-iii/SESSION_III_HANDOFF.md), [night-session-iii/SESSION_III_ADVERSARIAL_REPORT.md](night-session-iii/SESSION_III_ADVERSARIAL_REPORT.md) |
| SABOTEUR | Grok `bc-2032ba8f-2da1-57fc-b9c1-e20342f6ee06`. First review HOLD on in-flight identity. Repair `b8bf57d45d6812f9659d1945c64e0e53d7b41bc4`. Second review PASS. No production edits by the reviewer. |
| FOUNDATION DELTAS | NONE |
| DOMAIN DELTAS | NONE |
| HUMAN EVIDENCE | NONE. Founder pilot not run. |
| LOCAL GATES | Unchanged. LOCAL GATE REQUIRED. |
| NEXT | Founder diagnostic pilot only. Not a decisive human-performance sample. |
