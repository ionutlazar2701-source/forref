# Program ledger

Status of this file: RECORD — NOT A PASS

No Founder PASS. No Match Authority PASS. No Don PASS. No Tony PASS.

The older branch `cursor/forref-wave1-integration-30fd` is a previous test and harness wave. It is not V2 WAVE 1. V2 WAVE 1 means Goal and Score as defined in the V2 research, and it stays HOLD.

## WAVE 0

| Field | Value |
| --- | --- |
| STATUS | HOLD |
| PARENT SHA | `32eded4e8d18fa0165bb170209afe9b3b0ee5e29` |
| EXECUTION SHA | Tip of `cursor/forref-wave0-contract-freeze-30fd` after the contract-pack commit. 002D correction commit: `35c10a20016d9955eee92f84f911ebd2c5a85374`. The contract-pack hash is the parent of any later test-stamp commit and is recorded in `WAVE0_HANDOFF.md` once that commit exists. |
| BRANCH | `cursor/forref-wave0-contract-freeze-30fd` |
| SUBAGENT | FORREF WAVE 0 domain/architecture reviewer. Requested model: grok-4.7-high. Actual model: Grok 4.7. |
| OWNED FILES | `docs/forref-development/**`. Surgical factual corrections in `docs/forref-execution/` only where a missing-SHA claim for `fda5af6` or `research/watch_core_r1` was stated: `RESEARCH_TO_REPO_AUDIT.md`, `RISK_REGISTER.md`, `NEXT_WAVE.md`, `DEPENDENCY_GRAPH.md`, `WAVE_EXECUTION_PLAN.md`, `HANDOFF_RO.md`. |
| TESTS | `cd packages/forref_match_core && dart test`. Result filled in `WAVE0_HANDOFF.md` after the run. Label is TEST EXECUTED PASS or TEST EXECUTED FAIL. That label does not authorize domain semantics. |
| ADVERSARIAL RESULT | HOLD. Governance contradiction recorded and not applied. Domain contracts are drafts. Two goal forks conflict with each other and their integer `0–0` empty score conflicts with the score hard rule. Legacy injury, red, and substitution writers remain on the phone cutover line. No sporting-law invention. No authority PASS. |
| HOLDS | Founder scope. Match Authority freeze. Visual design. Injury decision. Goal payload choice. Score known-zero predicate. Cautions "No" predicate. Enter-field semantic from PR #9. PR #9 store serializer. |
| LOCAL GATES | LOCAL GATE REQUIRED. PHYSICAL DATA REQUIRED. HARDWARE EVIDENCE ABSENT. Power-loss D1 is not certified. No device was operated. |
| AUTHORITY GATES | Founder sign-off REQUIRED and not issued. Match Authority freeze not issued. Don PASS not issued. REFEREE DATA REQUIRED. HUMAN EVIDENCE ABSENT. Tony PASS not issued. |
| NEXT WAVE | V2 WAVE 1 (Goal+Score) is HOLD until an accepted WAVE 0 SHA is explicitly supplied by Product Command. Do not start it. `cursor/forref-wave1-integration-30fd` is not that wave. |

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

One integration owner per wave for each of those groups. This wave changed none of them.
