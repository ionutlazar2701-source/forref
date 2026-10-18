# Domain contract — YELLOW_CARD

Status: HISTORICAL WAVE 0 DRAFT — not the canonical contract

Canonical statement: [FOUNDATION_FREEZE.md](FOUNDATION_FREEZE.md). Yellow implementation is outside WAVE 1. Product Command acceptance of the freeze SHA is still pending.

Parent vocabulary has no `YELLOW_CARD` code. Disciplinary facet id exists and is not a cautions model.

Off-main evidence, not accepted:

- PR #5 `901601f2d5a6b16ed46333021e1fbf5c62b2c0da` adds `MatchParticipantId` and says it is not a shirt number. `DisciplinaryAccountingScope` has `match`, `shootout`, and `unresolved`.
- PR #6 `92d3a70c48e66c7c123b334010a6db36f8538956` adds `YellowCardSemantic` and `YellowCardPayload` (`participantRef`, status at determination, accounting scope, `captureIntentId`, optional reason). The semantic text says the record means a caution was administered, not a pending intention, and not an automatic second-yellow consequence.
- Later PR #7 through PR #10 build projection and phone capture on that line. They are classified in the reuse matrix. They are not frozen.

Law citations in the V2 research are planning notes. This draft does not expand them.

## Hard rules (verbatim)

Two yellow records must not synthesize a RED_CARD record. Second-caution awareness may be derived. Sending-off stays an explicit referee act.

MATCH and SHOOTOUT accounting are distinct. Shirt number is not identity.

Saved only after DurableCommitSuccess. RAM, queue, API, Bluetooth, cloud, and optimistic UI are not Saved.

## Invariants

- A yellow record means a caution was administered. It does not mean an intention, a pending caution, or a physical card object.
- The participant is a stable `MatchParticipantId` (or a draft equivalent that resolves to one). Participant status at determination is historical context. It is not identity.
- Shirt number is not identity. Two people may use the same number. One person keeps one id across a status change.
- Accounting scope is explicit. MATCH and SHOOTOUT are different ledgers. An unresolved scope is not silently treated as MATCH.
- A capture intent id identifies one deliberate act for retry. It is not sporting meaning.
- A second standing caution may be surfaced as awareness. That awareness is derived. It is not a `RED_CARD` record.
- Two yellow records must not synthesize a RED_CARD record. Second-caution awareness may be derived. Sending-off stays an explicit referee act.
- The yellow record is immutable after commit. Withdrawal is a new record.
- Saved only after DurableCommitSuccess. RAM, queue, API, Bluetooth, cloud, and optimistic UI are not Saved.

## Fail-closed modes

- Missing participant, ambiguous participant, or shirt number used as the only identity: do not commit.
- Scope missing or unresolved: do not commit into the MATCH ledger and do not commit into the SHOOTOUT ledger.
- Authority closed, wrong generation, or not the single writable main-referee authority: do not commit.
- Duplicate intent: do not append a second yellow for that intent.
- Identity conflict or contradictory reconciliation: the disciplinary facet conflicts. Do not choose a winner by timestamp.
- Unsupported competition disciplinary system, if a system pin is required: do not commit. This draft does not name the systems.
- Any attempt to append `RED_CARD` because two yellow records exist: forbidden.
- Commit result other than `DurableCommitSuccess`: no Saved.

## Minimum tests

- Caution to an on-field player, to a substitute, and to a substituted player, under the same stable id when it is the same person.
- Same shirt number, different participant ids: two ledgers, not one.
- Provisional id reconciled to a canonical id: standing caution follows the canonical id. A conflicted reconciliation does not.
- Failed commit then retry of the same intent: one yellow after success, none saved on failure.
- MATCH yellow does not appear as a SHOOTOUT yellow.
- SHOOTOUT yellow does not appear as a MATCH yellow.
- Two standing MATCH yellows for one canonical participant: second-caution awareness may be true; the log contains no `RED_CARD` record.
- Legal withdrawal: original yellow remains; it no longer stands; awareness recomputes.
- Unresolved scope: no standing caution in either ledger.

## Unresolved questions

- Match Authority: the exact participant-ref cases (player, substitute, substituted player, team official) that a yellow may target. PR #6 carries a status-at-determination field. The allowed set is not frozen here.
- Match Authority: whether a reason string is optional enrichment only, as the PR #6 payload comment says, or a required classified basis. Not frozen.
- Match Authority: which disciplinary systems are in FTM. PR #7's projection can fail closed on an unsupported system. The list is not adopted.
- Match Authority: whether second-caution awareness is a count, a boolean, or both, and whether it is shown during capture. Derivation is allowed. A red record is not.
- Engineering: PR #9's phone history contains the yellow capture UI and also changes `SqliteDurableMatchStore` serialization. The store change is not part of this contract. See the reuse matrix.
- Founder: yellow scope is not signed off.

## Authority

Match Authority owns who can be cautioned and what the record means. Not issued.
Engineering owns identity representation and the commit port. Not issued.
Don owns whether a referee can understand the capture. Not issued. HUMAN EVIDENCE ABSENT.
