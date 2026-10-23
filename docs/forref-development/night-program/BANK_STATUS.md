# Bank status

Phase I saboteur: Grok `bc-643fcb68-2356-53b6-8458-a2fa6e0f2ced`. Reviewed behavior SHA `f0f5e968925921139e41da06a9a384cc2078ba78`. Analyzer-only tip `09fa0bf39bbf7b1aecaef8aa56a780b8b1249f7c` changes no behavior. Test-only attacks: `cd6e2a952a7412cce8628f5bddf99f7e43bf459a`. 23 passed, exit 0. The reviewer did not edit `lib/`.

Phase II saboteur: Grok `bc-b4ae2960-049d-5a4d-921d-b09ea16902a0`. Final review PASS on `39a676b25682e2b6930b6d4f7f02340b55ae01a8`. The reviewer did not edit `lib/`. See [PHASE2_ADVERSARIAL_REPORT.md](PHASE2_ADVERSARIAL_REPORT.md).

| Bank | Status | SHA | Summary |
| --- | --- | --- | --- |
| A Participant identity | PASS | `6d9549da23e87b66e4a7528e71dcae2ec767fbf5` | Opaque `MatchParticipantId`. Match scope is `MatchScopedParticipantId`. Situation and shirt label are outside the token. No reconciliation API. |
| B Yellow card | PASS | `09fa0bf39bbf7b1aecaef8aa56a780b8b1249f7c` | PARTICIPANT-YELLOW BANK. Administered caution, explicit MATCH or SHOOTOUT scope, capture intent, generation-1 root admission. Team-official Yellow is BANK B2. |
| C Cautions awareness | PASS | `09fa0bf39bbf7b1aecaef8aa56a780b8b1249f7c` | Read-only. Known standing, known none, unavailable, and conflicted are distinct. Known none uses the existing completeness proof. Two standing cautions set factual awareness and write no SEND_OFF. |
| G Team-official identity | PASS | `87f8cce1e031b152614c9dc08fdae5d44152eb82` | `MatchTeamOfficialId` and match scope. Sealed participant or team-official subject. One trusted team binding. Kind is part of equality. |
| B2 Team-official Yellow | PASS | `0ff1ae4ec7cafac6d3d4e48347811dda07885ce8` | Yellow payload schema 2. v1 participant bytes stay v1 and normalize at read time. Team-official Yellow is v2 only. |
| D SEND_OFF | PASS | `65cd62f94f4637541c6524f27e6f0024c50fbb15` | Explicit direct or second-caution SEND_OFF. Two yellows do not create one. Y1 and Y2 must be this match. Match-scope repair `39a676b25682e2b6930b6d4f7f02340b55ae01a8`. |
| E Substitution / status | PASS | `02a8e5737023a05f90126201ef485274e4d6d3f6` | Completed OUT/IN transition with team proof. Status is a projection. No competition-rules engine. |
| F Disciplinary lifecycle | PASS | `09fa0bf39bbf7b1aecaef8aa56a780b8b1249f7c` | `REFEREE_ENTERED_FIELD_FOR_MATCH_START` is its own payload. It is not `MATCH_STARTED` and it is not inferred from the clock. No post-match exit fact was added. |

Historical reuse, not merged:

| Source | Class | Taken | Rejected |
| --- | --- | --- | --- |
| PR #5 `901601f2d5a6b16ed46333021e1fbf5c62b2c0da` | PARTIAL REUSE | Opaque participant id is not a shirt number. | Branch architecture, registration, and reconciliation payloads. |
| PR #6 `92d3a70c48e66c7c123b334010a6db36f8538956` | PARTIAL REUSE | Administered caution, explicit scope, capture intent. | Optional reason as authority, and that branch's serializer. |
| PR #7 `b8eae3cea9b468ea56f75dfd6aee3f08595aec55` | PARTIAL REUSE | Separate none / standing / unresolved answers. | A zero count on the unresolved state. |
| PR #9 `ac82959` | REJECT | The night program names the field-entry fact. The SHA was not imported. | Store serializer and `REFEREE_LEFT_FIELD_AFTER_MATCH`. |
| PR #10 | REJECT | None. | Legacy phone capture and store serializer changes. |

Foundation semantics are unchanged.
