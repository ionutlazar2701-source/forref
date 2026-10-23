# Score trust fail-closed evidence

## Identity

- model_actual: Grok 4.7
- model_preference_requested: grok-4.7-high
- branch: `cursor/forref-wave1-score-trust-30fd`
- base_commit: `919c9062d607f0af255ad368b8c6cb2658d6c85a`
- evidence_commit_message: `test: lock fail-closed score projection trust`
- evidence_commit: the commit on this branch whose parent is `919c9062d607f0af255ad368b8c6cb2658d6c85a` and whose message is `test: lock fail-closed score projection trust`. That commit introduces this report and the adversarial test. No later SHA is baked into this file.

## Commands

`fvm` is not on `PATH`. `.fvm/fvm_config.json` exists and pins Flutter `3.47.2`. The fallback toolchain was Dart SDK `3.13.2` (`/usr/local/bin/dart`).

Ran from `packages/forref_match_core` on branch `cursor/forref-wave1-score-trust-30fd` at base `919c9062d607f0af255ad368b8c6cb2658d6c85a`. `git rev-parse HEAD` was that base before and after the run.

```text
dart analyze
dart test test/adversarial/score_trust_fail_closed_test.dart
dart test
```

## Results

| Command | Result |
| --- | --- |
| `dart analyze` | No issues found |
| `dart test test/adversarial/score_trust_fail_closed_test.dart` | 9 passed, 0 failed |
| `dart test` (full `forref_match_core` suite) | 138 passed, 0 failed |

HOLD: none. The new assertions pass against unchanged `lib/`.

## Files

Added:

- `packages/forref_match_core/test/adversarial/score_trust_fail_closed_test.dart`
- `docs/forref-execution/evidence/score-trust/REPORT.md`

No file under `lib/` was modified. `pubspec.yaml`, `pubspec.lock`, `tool/`, `apps/`, `packages/match_core/`, `packages/forref_match_persistence/`, and existing tests were not modified. No semantic type code, score field, or Saved acknowledgement was added.

## What the tests lock

`DeterministicMatchProjector` with `ProductionSemanticsResolver` does not expose a home/away numeric score.

For every `V1SemanticTypeCode` (`MATCH_STARTED`, `PERIOD_STARTED`, `PERIOD_ENDED`, `TEMPORARY_SUSPENSION_STARTED`, `TEMPORARY_SUSPENSION_ENDED`, `MATCH_ABANDONED`, `MATCH_ENDED`, `TEMPORAL_CORRECTION`, `CORRECTION`, `LEGAL_SUPERSESSION`):

- The v1 contract does not create sporting state and does not list `ProjectionFacet.score`.
- A supported production projection keeps `ProjectionFacet.score` at `ProjectionTrust.untrusted`.
- Temporal or coverage trust on that same projection does not promote the score facet.

`StructuredPayload` fields `scoreHome`, `scoreAway`, `home`, and `away`, and `semanticType` values `GOAL` and `YELLOW`, stay `SemanticSupportStatus.unsupported` on every `RecordKind`. The committed record remains in the projection and the score facet stays `ProjectionTrust.untrusted`.

A foundation payload key `facet: score`, which `FoundationPayloadSemanticsResolver` would treat as score support, stays unsupported under `ProductionSemanticsResolver`. Score trust stays `ProjectionTrust.untrusted`.

`MatchProjectionState` declares facet trust and no home/away integer score field. The only declared `int` field in that class is `evaluatedAuthorityGeneration`. `trustFor('scoreHome')`, `trustFor('scoreAway')`, `trustFor('home')`, and `trustFor('away')` return `ProjectionTrust.untrusted`.

## GOAL-like payload

Record `goal-1`, `RecordKind.action`, payload `semanticType: GOAL` plus `scoreHome: 1`, `scoreAway: 0`, `home: '1'`, `away: '0'`, projected beside a supported `MATCH_STARTED` record:

- Resolver status: `SemanticSupportStatus.unsupported`
- Supported facets: empty (score is not supported)
- Temporal facet: `ProjectionTrust.trusted` from `MATCH_STARTED`
- Score facet: `ProjectionTrust.untrusted`
- Score facet reason: `no explicit projection semantics declared`
- `goal-1` remains in `committedRecordIds` and in `unsupportedSemanticRecordIds`

## Gaps

A frozen Score Projection Trust Contract is absent from this repository. The research claim that such a contract is already frozen is false. This evidence does not invent that contract.

Also absent:

- A numeric score contract (no home/away score numeral on `MatchProjectionState`, and no production semantic that means Goal).
- A freshness contract for score.
- A completeness contract for score.

Legacy `packages/match_core` still contains a mutable score calculator. That package is legacy. This lock does not import it and does not edit it.

## Explicit boundary

This is not a Score Projection Trust freeze.

This is not production score approval.

DOMAIN AUTHORITY REQUIRED for any future numeric score.

## Gates

| Gate | Status |
| --- | --- |
| IMPLEMENTATION | NOT APPLICABLE |
| TEST | PASS |
| DOMAIN | REQUIRED |
| ARCHITECTURE | NOT APPLICABLE |
| RELIABILITY | PASS |
| INTEGRATION | NOT APPLICABLE |

IMPLEMENTATION is not applicable because production `lib/` is unchanged. DOMAIN AUTHORITY REQUIRED remains for any future numeric score. ARCHITECTURE is not applicable because no Score Projection Trust contract was frozen. INTEGRATION is not applicable because phone, persistence, and watch clients were not changed.
