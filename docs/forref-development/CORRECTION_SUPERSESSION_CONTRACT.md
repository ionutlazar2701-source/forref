# Correction and legal supersession

Status: DRAFT — NOT FROZEN

No Founder PASS. No Match Authority PASS. No Don PASS. No Tony PASS.

Parent already has `V1SemanticTypeCode.correction` and `V1SemanticTypeCode.legalSupersession`. Both require a target relationship. Both use `SemanticEffect.historicalInterpretation`. Both set `createsSportingState` to false. Their projection facet on the parent is coverage, not score and not disciplinary.

That parent contract is the structural base. It does not define the sporting effect of correcting a goal, a yellow, a red, or a substitution, because those event types are not in the parent vocabulary.

PR #2 comments say a correction amends the stored goal account while the determination stands, and a legal supersession withdraws the scoring effect. PR #7's tip commit `b8eae3cea9b468ea56f75dfd6aee3f08595aec55` propagates disciplinary correction conflicts into `DisciplinaryMatchProjection`. Those are candidate behaviors. They are not frozen, and the PR #7 nickname "disciplinary projection" does not describe the tip commit. The projection was added by ancestor commits on that PR; the tip only propagates conflicts.

## Hard rules (verbatim)

Two yellow records must not synthesize a RED_CARD record. Second-caution awareness may be derived. Sending-off stays an explicit referee act.

Saved only after DurableCommitSuccess. RAM, queue, API, Bluetooth, cloud, and optimistic UI are not Saved.

UNKNOWN SCORE ≠ KNOWN 0–0. Never use home=0, away=0 as unknown.

## Invariants

- Match Memory is append-only. A committed record is not mutated and not deleted to correct history.
- A correction or legal supersession is a new record.
- The target relationship is explicit. The original record id remains.
- The legal effect is typed once Match Authority freezes the effect. Until then, a generic correction must not be treated as a sporting edit.
- Links do not form cycles.
- Two competing corrections or supersessions that disagree do not resolve by timestamp, origin sequence, or last write. The affected facet becomes conflicted.
- A correction of identity does not merge people by shirt number.
- Withdrawing a yellow does not rewrite that yellow into a red, and does not synthesize a red from the yellows that remain.
- Saved only after DurableCommitSuccess. RAM, queue, API, Bluetooth, cloud, and optimistic UI are not Saved.

## Fail-closed modes

- Missing target: do not commit.
- Target cycle, including a correction that targets itself through a chain: do not commit. If a cycle is already stored, projection of the affected facet is conflicted or untrusted, not silently truncated.
- Two competing corrections of the same sporting effect: conflict. No arbitrary winner.
- A generic correction payload that tries to change a sporting field the frozen effect list does not allow: reject.
- Authority generation of the correction inconsistent with the single writable generation: do not commit.
- Using correction to hide a failed commit or to manufacture Saved: reject.
- Using supersession of yellow records to append `RED_CARD`: reject.

## Minimum tests

- Goal withdrawal and goal replacement, once goal exists: original goal remains; standing effect follows only the new legal record; replay order is deterministic.
- Identity correction and provisional-to-canonical reconciliation: history still shows the earlier id; standing facts follow the canonical id; a conflicted map does not pick one.
- Caution withdrawal: yellow record remains; standing count drops; second-caution awareness recomputes; no red record appears.
- Red correction, once red exists: original red remains.
- Missing target: rejected.
- Cyclic target: rejected or, if replayed from storage, the facet does not choose a winner.
- Two conflicting branches: same facet, `ProjectionTrust.conflicted`, no numeric score invented from either branch.
- Rebuild twice: identical projection.

## Unresolved questions

- Match Authority: the typed effect list. Which goal fields, if any, a `CORRECTION` may amend while the goal still stands, and which acts must be `LEGAL_SUPERSESSION`. PR #2's comment is a candidate, not a decision.
- Match Authority: the same split for yellow reason, yellow participant, red basis, and substitution participants.
- Match Authority: whether a supersession without a supported effect code is stored as an unsupported record (parent behavior for unknown semantics) or refused at admission.
- Engineering: parent correction records do not create sporting state. A later interpreter that applies sporting effects must be a new explicit contract, not an inference from `RecordKind`.
- Engineering: PR #7 conflict propagation is limited to the disciplinary projection on that branch. It is not a general cycle checker for every facet. Not reused as the whole contract.

## Authority

Engineering architecture owns append-only structure, cycles, and conflict-not-winner. The parent ADR index already requires append-only history and no last-write-wins. This draft does not amend that index.
Match Authority owns the sporting effect of each correction type. Not issued.
Founder scope: not issued.
