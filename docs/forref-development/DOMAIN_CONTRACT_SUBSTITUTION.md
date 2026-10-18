# Domain contract — SUBSTITUTION

Status: DRAFT — NOT FROZEN

No Founder PASS. No Match Authority PASS. No Don PASS. No Tony PASS.

Parent vocabulary has no substitution semantic type. PR #2 through PR #12 do not add one. On PR #10, substitution still opens the legacy capture overlay and `session.saveEvent`. That path is not this contract.

The V2 research cites Law 3 as a planning note about when a substitution is complete. This draft does not expand that citation into a procedure, a return-substitution table, or a competition profile.

## Hard rules (verbatim)

MATCH and SHOOTOUT accounting are distinct. Shirt number is not identity.

Saved only after DurableCommitSuccess. RAM, queue, API, Bluetooth, cloud, and optimistic UI are not Saved.

Injury is OUTSIDE the drafted event set. A substitution contract must not be used to store an injury. Decision required for injury: hide/disable for FTM, or stop for an Injury contract. Do not choose.

## Invariants

- A completed substitution names the outgoing participant and the incoming participant as stable ids.
- Both participants are on the same team. Same-id in and out is not a substitution.
- Shirt number is not identity. The number may change or be reused without becoming the id.
- Status transition is recorded at completion, not when the referee opens the control and not when a request is only intended.
- What "complete" means for FTM is unresolved. This draft does not adopt a law paraphrase as the software rule.
- Whether a substituted player may return is a competition-profile input. It is not inferred from the event type.
- An incomplete substitution is not stored as a completed one.
- Correction of a substitution is a new record. The original remains.
- A later caution for the same person uses the same participant id. The substitution does not mint a new identity.
- MATCH and SHOOTOUT accounting are distinct. This draft does not define a shootout substitution. It forbids folding one into the other by default.
- Saved only after DurableCommitSuccess. RAM, queue, API, Bluetooth, cloud, and optimistic UI are not Saved.

## Fail-closed modes

- Cross-team outgoing and incoming: do not commit.
- Same participant id in both roles: do not commit.
- Incoming not eligible under the active competition profile: do not commit. If the profile is unknown, do not assume eligibility and do not assume a ban on return.
- Outgoing participant is not an active on-field participant at the determination: do not commit as complete.
- Incomplete substitution written as complete: reject.
- Return substitution where the profile does not allow return: do not commit. Where the profile is silent: do not commit.
- Shirt number used as the only identity for either participant: do not commit.
- Commit result other than `DurableCommitSuccess`: no Saved.
- Using this event to record an injury: reject. Injury is outside this contract.

## Minimum tests

- One completed substitution, same team, two stable ids, status projection changes only after `DurableCommitSuccess`.
- Halftime and extra time, once those phases are defined by temporal records rather than by a display clock. The phase set is not frozen here; tests must use the temporal records that exist, not a widget minute.
- Failed D1: no Saved, no status change in the rebuilt projection.
- Return allowed by an explicit test profile, and return refused by an explicit test profile. A missing profile is a third case and must fail closed.
- Correction: original substitution record remains; standing status follows the new record.
- The incoming or outgoing person later cautioned: the caution uses the same id.
- Legacy `EventType.substitution` is not a second writer. Removal is a cutover decision.

## Unresolved questions

- Match Authority: the completion condition. Not taken from the research law note.
- Match Authority: which competition profiles exist for FTM, and the default when the profile is absent. This draft only requires fail-closed.
- Match Authority: whether substitutions exist in a shootout for FTM. Not specified.
- Match Authority: concussion or other special return paths. Not specified. Do not invent them.
- Founder: substitution is in the research FTM table and is not signed off.
- Engineering: there is no branch to reuse. Classification is ABSENT for a new semantic, and CONFLICTING on phone branches that still save substitutions through `MatchSession`.

## Authority

Match Authority owns completion and eligibility. Not issued.
Engineering owns the record shape after that freeze. Not issued.
Founder owns FTM scope. Not issued.
