# Phase II execution manifest

Status of this file: RECORD

## Execution base

PHASE2_EXECUTION_BASE_SHA: `f4bf48ffd397b1cd81cf2f40a08084aa49561b7e`

That SHA is the Phase I evidence tip. `git merge-base --is-ancestor` confirms it descends from production `09fa0bf39bbf7b1aecaef8aa56a780b8b1249f7c`. The library diff `09fa0bf..f4bf48f` under `packages/**/lib` and `apps/**/lib` is empty. The commits between those SHAs are test and documentation evidence only.

Branch: `cursor/forref-night-phase2-30fd`

Phone production cutover: not in this manifest. No file under `apps/**/lib` changes in this phase.

## File map used

| Concern | Location |
| --- | --- |
| Participant identity | `packages/forref_match_core/lib/match_participant.dart` |
| Team-official identity and subject ref | `packages/forref_match_core/lib/disciplinary_subject.dart` |
| Yellow v1, Yellow v2, SEND_OFF, substitution payloads | `packages/forref_match_core/lib/semantics/v1_semantic_payload.dart` |
| Semantic codes | `packages/forref_match_core/lib/semantics/match_record_semantic_type.dart` |
| Capture intent | `packages/forref_match_core/lib/capture/yellow_capture_intent.dart` |
| Substitution admission | `packages/forref_match_core/lib/capture/substitution_admission.dart` |
| Effective Yellow | `packages/forref_match_core/lib/projection/effective_yellow_resolver.dart` |
| Effective SEND_OFF | `packages/forref_match_core/lib/projection/effective_send_off_resolver.dart` |
| Caution awareness | `packages/forref_match_core/lib/projection/caution_awareness.dart` |
| History completeness | `packages/forref_match_core/lib/projection/score_completeness_proof.dart` |
| Participant status | `packages/forref_match_core/lib/projection/participant_status_projection.dart` |
| Canonical form | `packages/forref_match_core/lib/canonical_record_form.dart` |
| Persistence encoding | `packages/forref_match_persistence/lib/record_storage_encoding.dart` |
| SQLite admission | `packages/forref_match_persistence/lib/sqlite_durable_match_store.dart` |

## Exclusive ownership

One writer for this phase: Match Core plus the persistence adapter that stores its records. The phone Live Match boundary was not an owner. Legacy `packages/match_core` was not extended.

## Wave DAG

```
f4bf48f
  N16 BANK G team-official identity
    N17 BANK B2 Yellow v2
      N18 BANK D explicit SEND_OFF
  N19 BANK E substitution          (depends on BANK A, already PASS)
    N20 status ↔ awareness         (B2 + E + BANK C)
      N21 awareness ↔ SEND_OFF     (D + N20)
        N22 cross-domain saboteur
          N23 verify_cloud
```

BANK E does not depend on SEND_OFF. The bridges start only after their banks.

## Schema migration

Match Record `schemaVersion` stays 1. Yellow payload schema is separate.

- Yellow v1 remains `participantId` and `yellowSchemaVersion` 1. Stored v1 bytes are not rewritten.
- Yellow v2 adds `DisciplinarySubjectRef` at payload schema 2. Team-official Yellow is v2 only.
- `SEND_OFF` and `SUBSTITUTION` are new semantic codes on schema 1 payloads.
- SQLite adds nullable capture-intent columns (`subject_kind`, subject id, `pathway`, caution record ids, substitution endpoints, `substitution_team_id`) and tables `team_official_team_bindings` and `participant_team_bindings`. Existing rows stay valid.

## Test plan

Bank tests live next to the package that owns the behavior: `phase2_yellow_v2_test.dart`, `phase2_send_off_test.dart`, `phase2_substitution_test.dart`, `phase2_status_awareness_test.dart`, `phase2_awareness_send_off_test.dart`, plus the persistence admission suites. The independent saboteur file is test-only.

## STOP conditions observed

No generic Actor, Person, or Entity graph. No second completeness engine. No second relationship graph. No competition-rules engine. No phone cutover. No injury semantic. No watch client.

Foundation delta: none. Domain delta: none. The sporting questions named in the Phase I hold packets were closed by this Product Command before implementation.
