# Score projection and trust

Status: DRAFT — NOT FROZEN

No Founder PASS. No Match Authority PASS. No Don PASS. No Tony PASS.

## Hard rules (verbatim)

UNKNOWN SCORE ≠ KNOWN 0–0. Never use home=0, away=0 as unknown.

Saved only after DurableCommitSuccess. RAM, queue, API, Bluetooth, cloud, and optimistic UI are not Saved.

MATCH and SHOOTOUT accounting are distinct. This sentence applies to score as well as to discipline: a match score and a shootout tally are not one number. The shootout tally is not defined here.

## Parent truth

`ProjectionFacet.score` exists (`packages/forref_match_core/lib/projection/projection_trust.dart`).
`ProjectionTrust` is `trusted`, `incomplete`, `conflicted`, or `untrusted`.
`MatchProjectionState` has facet trust, committed ids, missing dependencies, conflict notes, and unsupported semantic ids. It has no home integer and no away integer.
Parent production semantics do not trust the score facet for v1 codes. Adversarial tests on this parent reject smuggled `scoreHome` / `scoreAway` fields and assert that the projection type declares no home or away integer.

That fail-closed behavior stays the implementation truth until a frozen score contract exists. This draft does not replace it and does not authorize a numeral.

## Candidate conflict

PR #2 and the PR #3 line both introduce `GoalMatchProjection.homeScore` and `awayScore` as `int`, and both define an empty projection as `homeScore: 0, awayScore: 0`. PR #3 Live Match displays those integers when the new boundary is available, and otherwise displays `match.score.home` / `match.score.away` from the legacy aggregate.

That shape uses `home=0, away=0` as the empty value. It cannot be reused as the trust model. It is CONFLICTING with the hard rule. Green tests on those branches do not make the default correct.

A derived count of standing goals can be a known score only inside an explicit known state. The integer pair alone is not that state.

## Planning model (not adopted)

The V2 research sketches four display states:

```text
ScoreDisplayState
  ├── Known(home, away, evidenceFrontier)
  ├── Incomplete(reason)
  ├── Conflicted(reason)
  └── Unavailable(reason)
```

This draft records the sketch. It does not add the type. `Known` is the only state that carries a numeral. `Incomplete`, `Conflicted`, and `Unavailable` do not carry `0–0` as a placeholder.

How those four names map onto the existing `ProjectionTrust` values is unresolved. The parent enum has no separate `unavailable`. Do not collapse unknown into `trusted` with zeros.

## Invariants

- The numeric score and the trust state are separate. Trust is not implied by the presence of an integer.
- UNKNOWN SCORE ≠ KNOWN 0–0. Never use home=0, away=0 as unknown.
- A known score is derived only from goal records whose standing scoring effect the goal contract allows. It is not read from a mutable total on the goal payload.
- Match score and shootout tally are distinct. This draft does not define the shootout tally.
- Trust depends on coverage, dependencies, authority, conflicts, and freshness. The predicate for each input is unresolved.
- A stale replica is not the current score.
- Saved only after DurableCommitSuccess. RAM, queue, API, Bluetooth, cloud, and optimistic UI are not Saved. A score numeral that changed before that result is not Saved and is not current.

## Fail-closed modes

- Missing origin sequence or a gap that the freshness rule treats as incomplete: do not show a known numeral.
- Unsupported score event or a payload field such as `scoreHome`: do not trust score. Parent behavior already does this for smuggled fields.
- Stale replica presented as current: forbidden.
- Contradictory standing goal effects: `conflicted`, no chosen total.
- Unknown score rendered as `0–0`: forbidden.
- Legacy aggregate score shown beside, or instead of, a Match Memory score for the same match: forbidden once goal cutover is in scope. PR #3 still has that fallback. Not accepted.
- Shootout kicks added into the match score: forbidden. The kick representation is not specified here.

## Minimum tests

- Fresh match, score evidence complete, zero standing goals: a known `0–0` only if the known-state predicate is met. A fixture with no score facet must not look like that case.
- Standing goals producing 1–0, 2–1, and 3–3 after `DurableCommitSuccess`, then rebuild.
- Superseded goal: known total excludes it; history can still show it.
- Origin gap: not a known numeral.
- Unsupported semantic: score untrusted, no numeral.
- Out-of-order replication: same records, same known score; a missing record is incomplete, not a lower score.
- Stale replica: not displayed as current.
- Conflict: no numeral.
- Restart and rebuild: identical known score or identical non-known state.
- The assertion that `home=0, away=0` means unknown: must fail.

## Unresolved questions

- Match Authority: when zero standing goals are a known `0–0` (which coverage, which authority generation, which dependency set, which freshness).
- Match Authority: whether an untrusted or incomplete score may show a bounded hint. This draft forbids a numeral. It does not design the hint.
- Engineering: mapping of Known / Incomplete / Conflicted / Unavailable onto `ProjectionTrust`. Not decided.
- Engineering: any reuse of `GoalMatchProjection` must split the empty integer default from a known zero before it can satisfy this contract. No branch has that split.
- Founder: score display comprehension is also a Don question. No Don PASS. HUMAN EVIDENCE ABSENT.

## Authority

Match Authority owns when a numeral is true. Not issued.
Engineering owns the trust algorithm after that meaning is frozen. Not issued.
Don owns whether the non-numeric states are understandable. Not issued.
