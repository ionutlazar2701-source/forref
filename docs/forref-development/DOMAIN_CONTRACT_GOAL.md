# Domain contract — GOAL

Status: HISTORICAL WAVE 0 DRAFT — not the canonical contract

Canonical Goal statement for a future WAVE 1: [WAVE1_GOAL_SCORE_CONTRACT.md](WAVE1_GOAL_SCORE_CONTRACT.md). Summary: [FOUNDATION_FREEZE.md](FOUNDATION_FREEZE.md). Product Command acceptance is still pending. This draft is not a second Goal contract.

Parent vocabulary has no `GOAL` code. `V1SemanticTypeCode` does not include it. `createsSportingState` is false for every parent code. This draft does not add a code.

Two incompatible goal shapes exist off `main` and off this parent. Neither is selected.

- PR #2 `3c2a37dada8560765c45597975b67edd8d422448`: `GoalPayload` with `scoringSide`, `period`, optional `playerId`, optional `playerNumber`; admission in `goal_admission.dart`; comment that an own goal is the same determination for the credited side.
- PR #3 `4e602485c2a9bb85754b7cdb060ac16ac1318aed` and its descendants through PR #10: `GoalPayload` with `creditedSide` and `captureIntentId`. No period field on the payload. No player fields. Phone `commitGoal` exists. PR #2 is not an ancestor of this line.

Law citations in the V2 research are planning notes. This draft does not expand them.

## Hard rules (verbatim)

UNKNOWN SCORE ≠ KNOWN 0–0. Never use home=0, away=0 as unknown.

Saved only after DurableCommitSuccess. RAM, queue, API, Bluetooth, cloud, and optimistic UI are not Saved.

## Invariants

- A goal record is a human determination by the main referee that a goal stands for one side.
- The credited side is required. The side is the team that is awarded the goal.
- An own goal, if recorded, is still a determination for the explicitly credited side. It is not a goal for the team that last touched the ball unless that is the side the referee credits.
- Scorer identity is optional enrichment. A missing scorer does not block the goal.
- Shirt number is not the scorer's identity. Shirt number is not team identity.
- The goal record does not store a mutable match total.
- Temporal placement refers to active period evidence. A display minute is not the authority for that placement.
- The score projection is derived. It is not a second stored authority.
- A legal withdrawal or supersession is a new record. The original goal record remains.
- Duplicate capture of the same deliberate intent must not append a second standing goal. How that intent is identified is unresolved below.
- Saved only after DurableCommitSuccess. RAM, queue, API, Bluetooth, cloud, and optimistic UI are not Saved.

## Fail-closed modes

- Unknown or missing credited side: do not commit.
- Capture authority is not `MAIN_REFEREE`, or the authority generation does not match the single writable generation: do not commit.
- Period placement does not match the active period evidence the contract eventually requires: do not commit. The required anchor shape is unresolved.
- Missing causal anchor, where the frozen contract requires one: do not commit.
- Duplicate intent: do not append another standing goal.
- Unsupported payload: do not commit and do not treat the record as a goal.
- `DurableCommitFailure`, or any result other than `DurableCommitSuccess`: do not acknowledge Saved and do not show a new numeral.
- Contradictory supersession: the score facet conflicts. It must not pick a winner by timestamp or by last write.
- A payload that carries `scoreHome` / `scoreAway` as the authority: reject. Parent tests already keep smuggled score fields off the trusted score facet.

## Minimum tests

- Home goal and away goal, each credited explicitly, each visible in a derived score only after `DurableCommitSuccess`.
- Own goal represented only through the credited side, once the representation question below is closed. Until then, do not invent an own-goal boolean in this draft.
- Scorer absent: goal still commits if the side and the other frozen fields are present.
- Period mismatch: rejected.
- Same intent retried after failure: no Saved on the failure; one standing goal after success.
- Same intent retried after success: no second standing goal.
- Legal withdrawal: original record remains; standing total no longer includes it; replay is deterministic.
- Rebuild from the committed log equals the pre-restart projection.
- A path that would display `home=0, away=0` because the score is unknown: forbidden. See `SCORE_TRUST_CONTRACT.md`.

## Unresolved questions

- Match Authority: which payload is the contract, the PR #2 shape (`scoringSide`, `period`, optional player fields) or the PR #3 shape (`creditedSide`, `captureIntentId`)? They disagree. This draft does not choose.
- Match Authority: is own goal only the credited side, or is an additional marker required? PR #2 comments say the credited side is enough. The PR #3 phone path observed here does not pass an own-goal flag into `commitGoal`. The legacy overlay still has an own-goal control for other event types. Not chosen.
- Match Authority: is period identity stored on the goal payload, only as a causal link to `PERIOD_STARTED`, or both?
- Match Authority: what is the idempotency key, and is it sporting meaning or only a capture key? PR #3 calls `captureIntentId` an idempotency key and not match time.
- Match Authority: which goal fields a generic `CORRECTION` may change, and which changes require `LEGAL_SUPERSESSION`.
- Engineering: PR #2 and PR #3 both derive `homeScore` / `awayScore` integers and define an empty projection as `0` and `0`. That conflicts with the score hard rule. Reuse must not copy that default. See the score contract.
- Founder: goal scope is not signed off.

## Authority

Match Authority owns the sporting meaning. Not issued.
Engineering owns representation and the commit port. Not issued.
Founder owns whether goal is inside FTM scope. Not issued.
