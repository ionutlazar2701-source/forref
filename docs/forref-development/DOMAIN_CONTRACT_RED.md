# Domain contract — RED_CARD

Status: DRAFT — NOT FROZEN

No Founder PASS. No Match Authority PASS. No Don PASS. No Tony PASS.

Parent vocabulary has no `RED_CARD` code. None of PR #2 through PR #10 adds a `RED_CARD` semantic type. That absence is not a red contract. It is evidence that sending-off has not been implemented in the new core.

On the yellow line, `DisciplinaryMatchProjection` can mark `isSecondStandingCaution` and says that flag is advisory and is not dismissal authority. That supports the prohibition below. It does not implement an explicit red.

On PR #10 the Live Match red button still uses the legacy overlay and `session.saveEvent`. That legacy path is a second writer, not the contract.

`docs/mvp-scope.md` already lists "second yellow auto-converted to red" among things v1 must not do. This draft does not reopen that product line and does not turn it into a red payload.

Law citations in the V2 research are planning notes. This draft does not expand them into categories of sending-off offences.

## Hard rules (verbatim)

Two yellow records must not synthesize a RED_CARD record. Second-caution awareness may be derived. Sending-off stays an explicit referee act.

MATCH and SHOOTOUT accounting are distinct. Shirt number is not identity.

Saved only after DurableCommitSuccess. RAM, queue, API, Bluetooth, cloud, and optimistic UI are not Saved.

## Invariants

- A red record is an explicit referee-administered sending-off. The software does not invent one.
- The participant is a stable id. Status at determination is context, not identity.
- Shirt number is not identity.
- Accounting scope is explicit. MATCH and SHOOTOUT stay distinct.
- Where the referee's act distinguishes a direct sending-off from a sending-off after a second caution, the record may carry that basis. The basis vocabulary is unresolved. Absence of a basis must not be filled by counting yellow records and writing a red.
- Two yellow records must not synthesize a RED_CARD record. Second-caution awareness may be derived. Sending-off stays an explicit referee act.
- A red record does not edit or delete the yellow records it relates to.
- Saved only after DurableCommitSuccess. RAM, queue, API, Bluetooth, cloud, and optimistic UI are not Saved.

## Fail-closed modes

- Two yellow records with no explicit red act: do not append `RED_CARD`.
- Wrong or ambiguous identity, including shirt number alone: do not commit.
- Authority closed or generation mismatch: do not commit.
- Unresolved accounting scope: do not commit into MATCH or SHOOTOUT.
- Duplicate sanction for the same capture intent: do not append a second red.
- Unsupported team-official case, until that case is explicitly allowed: do not commit.
- A generic correction that tries to turn a yellow into a red in place: reject. A new record is required.
- Commit result other than `DurableCommitSuccess`: no Saved.

## Minimum tests

- Direct sending-off of an identified participant: one red record after `DurableCommitSuccess`, and only then.
- Explicit red after a second caution: the two yellow records remain; the red record exists only because it was committed as its own act; the basis, once frozen, is stored on the red record.
- Two yellow records and no red act: zero `RED_CARD` records. Second-caution awareness may be derived.
- Player, substitute, and team official, once each is in the allowed set. Until the set is frozen, tests must not invent the official case as legal.
- Withdrawal of a red: original remains; standing sending-off effect ends only through the new record.
- A MATCH red does not stand in the SHOOTOUT ledger, and the reverse.
- Legacy `EventType.redCard` through `MatchSession` is not a second successful writer beside the new port. How the legacy control is removed is a founder and cutover decision, not a rule invented here.

## Unresolved questions

- Match Authority: the basis vocabulary for direct sending-off versus second-caution sending-off. Not invented here.
- Match Authority: which participant statuses may receive a red in FTM, including team officials.
- Match Authority: whether a red requires a link to prior yellow records when the basis is second caution, and what happens if those yellows are later withdrawn.
- Match Authority: shootout sending-off rules are not specified here. Only ledger separation is required.
- Founder: red is inside the research FTM table and is not signed off. The legacy phone UI still offers red.
- Engineering: no candidate branch is a red implementation to reuse. Classification for Red on PR #2–#10 is ABSENT for the record type, with PARTIAL only for the "do not synthesize" prohibition on the yellow projection line.

## Authority

Match Authority owns sending-off meaning. Not issued.
Engineering must not generate the record from yellow counts. Not issued as an implementation.
Don and Tony: no human or hardware PASS. HUMAN EVIDENCE ABSENT. HARDWARE EVIDENCE ABSENT.
