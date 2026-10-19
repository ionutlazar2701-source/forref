# Phase II test matrix

Status of this file: RECORD

| Suite | Package | What it locks |
| --- | --- | --- |
| `test/disciplinary_subject_test.dart` | Match Core | Empty official id rejected. Value equality. Match scope. Participant token `123` is not official token `123`. Serialization. Binding round-trip. Display attributes are outside identity. |
| `test/phase2_yellow_v2_test.dart` | Match Core | v1 participant payload stays schema 1. Read-time subject is the participant. v2 official round-trip. Same intent conflicts across subject kind, official id, and scope. MATCH and SHOOTOUT stay separate. Two yellows do not create SEND_OFF. |
| `test/phase2_send_off_test.dart` | Match Core | Direct and second-caution pathways. Missing, equal, mismatched, and non-yellow dependencies are unavailable. Roles are the named ids. Later yellow supersession does not delete SEND_OFF history. Superseding the SEND_OFF clears legal effect and keeps the record. |
| `test/phase2_substitution_test.dart` | Match Core | Completed OUT/IN transition. Same id throws. Status projects substituted and on-field. A later substitution restores on-field for the same id. |
| `test/phase2_status_awareness_test.dart` | Match Core | One history proof. Caution survives substitution. Team-official awareness uses the same evaluator. Unknown is not known-none. Score proof behavior stays on the same function. |
| `test/phase2_awareness_send_off_test.dart` | Match Core | Two yellows append no SEND_OFF. Explicit SEND_OFF keeps yellow ids and clears the active surface. A superseded SEND_OFF recomputes the surface. A missing dependency is unavailable. |
| `test/adversarial/phase2_saboteur_attack_test.dart` | Match Core | Independent cross-domain attacks. See [PHASE2_ADVERSARIAL_REPORT.md](PHASE2_ADVERSARIAL_REPORT.md). |
| `test/phase2_yellow_v2_admission_test.dart` | Persistence | Durable v1/v2 round-trip and team-official binding admission. |
| `test/phase2_send_off_admission_test.dart` | Persistence | Durable SEND_OFF intent, including pathway and named yellow ids. |
| `test/phase2_substitution_admission_test.dart` | Persistence | Durable substitution admission against participant team bindings. |
| `test/adversarial/phase2_saboteur_persistence_attack_test.dart` | Persistence | v1 JSON has no `subjectKind`. Intent collision across yellow and SEND_OFF. D1 abort stores no new row. |

Existing WAVE 1 score suites and the Phase I saboteur file still run inside `dart test`. Switches that gained `SEND_OFF` and `SUBSTITUTION` arms stay fail-closed for unsupported use.

Full-repository counts are in [PHASE2_HANDOFF.md](PHASE2_HANDOFF.md).
