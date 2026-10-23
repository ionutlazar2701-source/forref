# Phase II adversarial report

Status of this file: RECORD

Reviewer: Grok, agent `bc-b4ae2960-049d-5a4d-921d-b09ea16902a0`.

The reviewer did not edit `lib/`. Production repairs below were made by the orchestrator after a failing attack, then the same reviewer re-ran the attack file.

## Reviews

| Pass | Candidate | Result | Tests |
| --- | --- | --- | --- |
| 1 | `47d0b91ae5a730b1b8357e2729dfcbc3a56cbfe3` | AWARENESS ↔ SEND_OFF HOLD. A match-2 direct SEND_OFF for the same participant cleared the match-1 active surface. Other banks PASS. | 50 passed, 1 failed |
| Repair | `39db1e37e34bdf5bc948a722221a61c8b25f0f32` | Active SEND_OFF membership requires the SEND_OFF record `matchId`. | |
| 2 | `39db1e37e34bdf5bc948a722221a61c8b25f0f32` plus the new attack | AWARENESS ↔ SEND_OFF HOLD. Match-2 yellows made a match-1 second-caution dependency ready and closed the surface. | 48 passed, 1 failed |
| Repair | `39a676b25682e2b6930b6d4f7f02340b55ae01a8` | Y1 and Y2 must share the SEND_OFF match id. Otherwise the dependency is unavailable. | |
| 3 | `39a676b25682e2b6930b6d4f7f02340b55ae01a8` | PASS on every Phase II component. | 45 passed, 0 failed |

The third run is the certification run. It executed `test/adversarial/phase2_saboteur_attack_test.dart` and edited nothing.

## Component result

| Component | Result |
| --- | --- |
| BANK G | PASS |
| BANK B2 | PASS |
| BANK D | PASS |
| BANK E | PASS |
| STATUS ↔ AWARENESS | PASS |
| AWARENESS ↔ SEND_OFF | PASS |
| CROSS-DOMAIN | PASS |

## Attacks that stayed closed

- Participant token `123` is not team-official token `123`.
- A role-label map does not fork an official id. A second match scope does not alias it.
- Two team bindings for one official are ambiguous and are not trusted.
- Yellow v1 stays a participant payload at schema 1. Official Yellow is payload schema 2.
- An official Yellow without one trusted team binding is missing.
- The same capture intent cannot mean both a participant and an official, and cannot change scope.
- MATCH and SHOOTOUT do not leak.
- Two yellows create zero SEND_OFF records. Awareness does not append one.
- Direct SEND_OFF does not require yellow ids. A causal link on a direct SEND_OFF is unavailable.
- Y1 equal to Y2 throws. Missing Y2, wrong subject, wrong scope, a non-yellow dependency, and a relates-to link that is not causal are unavailable.
- First and second roles are the named record ids, not origin time.
- Same incoming and outgoing substitution id throws. Cross-team, missing, and ambiguous bindings are rejected. Matching bindings admit with no competition profile.
- A later substitution projects the same participant id on field.
- A null or incomplete history proof is not known-none.
- Substitution does not move the standing yellow to a new id.
- Explicit SEND_OFF keeps historical yellow ids and drops the active surface. A voided SEND_OFF opens it again. A shootout SEND_OFF does not close the match surface. An official SEND_OFF does not close the participant surface.
- A foreign origin, an origin gap, and a generation other than 1 make both history proofs not ready.

Persistence attacks in `phase2_saboteur_persistence_attack_test.dart` passed in the orchestrator run: stored v1 JSON has no `subjectKind`, yellow and SEND_OFF cannot share an intent, and a D1 abort writes no new admission.

## Production edits by the reviewer

NONE
