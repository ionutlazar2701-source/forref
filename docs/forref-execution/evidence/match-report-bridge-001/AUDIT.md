# Match Report authority bridge — gap audit

Functional baseline: `c993055fbeb4e769174aaf86d5aa4889ee95c21d` (`cursor/zepp-live-match-flow-002-30fd`). PR #45 True Black is untouched.

## Three histories that do not meet

| Path | What it stores | What a report can honestly say |
| --- | --- | --- |
| Zepp `Event → Player → Review` | In-memory `state()` plus the prototype clock file `forref_clock001c_state`. Event title is `DEMO — NOT RECORDED`. Review shows `DEMO — RECORDING NOT AVAILABLE`. | A selection. Not a Match Record. Not Saved. Not D1. |
| Phone legacy capture | Drift `Match` / `MatchSession` mutable aggregate. Summary still opens that session. | A legacy document. Not Match Memory. |
| Match Memory | Append-only records in `SqliteDurableMatchStore`, separate SQLite file `forref_match_memory/match_memory.sqlite`. | Only records that survived D1. Projection is rebuilt and disposable. |

S2.5R (`docs/forref-development/simulator/S2_5R_MATCH_REPORT_OPERATIONS.md`) is research-only. Its report is built from simulated saved rows in `research/simulator_hf_bridge`. The production firewall in that document still stands: research code is not the phone or Match Core writer.

## What Match Core already admits

Committed payloads with existing admission and resolvers:

- Goal — `GoalPayload`, `resolveEffectiveGoals`, score only through `ScoreCompletenessProof`
- Yellow — `YellowCardPayload` / `YellowCardPayloadV2`, `resolveEffectiveYellows`
- Send-off — explicit `SendOffPayload` (`direct` or `secondCaution`). Two Yellows do not create a send-off
- Substitution — `SubstitutionPayload` after `evaluateSubstitutionAdmission` and participant-team bindings
- Temporal transitions — `TemporalTransitionPayload` and `TemporalMatchProjection`

None of those event payloads carry an authoritative match minute. `recordedAt` and `TemporalContext.evidenceIds` are chronology. Exact event time stays unavailable.

## What this bridge does not close

- The Zepp JavaScript client cannot execute Dart Match Core.
- Prototype `LocalStorage` readback is not D1.
- The phone live and summary screens still read the legacy aggregate. This slice does not attach a second writer to that aggregate.
- LOTG offence reasons are not a v1 payload field. See `LOTG_REASON_FOLLOW_UP.md`.
