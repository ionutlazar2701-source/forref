# First Trustworthy Match

Status: HISTORICAL WAVE 0 DRAFT — not the canonical contract

Canonical statement: [FOUNDATION_FREEZE.md](FOUNDATION_FREEZE.md). Injury is out of FTM v1. Product Command acceptance of the freeze SHA is still pending. This file is not a second FTM contract.

First Trustworthy Match (FTM) is a draft acceptance description for one phone match whose displayed sporting claims are rebuilt from immutable Match Records, with Saved only after durable commit. It is not a demo script, not a release certification, and not Watch Live Core.

Parent: `32eded4e8d18fa0165bb170209afe9b3b0ee5e29`.
Repository ports checked, not changed: `MatchRecord`, `DurableCommitResult` / `DurableCommitSuccess`, `ProjectionTrust`, `ProjectionFacet`, `V1SemanticTypeCode`.

On this parent, `V1SemanticTypeCode` is temporal transitions plus correction and legal supersession. `createsSportingState` is false for every code. `ProjectionFacet.score` and `ProjectionFacet.disciplinary` exist. `MatchProjectionState` has no home or away numeral. That fail-closed score position is the parent truth. Candidate branches that introduce `homeScore` / `awayScore` integers are audited in `EXISTING_BRANCH_REUSE_MATRIX.md` and are not accepted here.

Law citations in the V2 research are planning notes. This draft does not expand them into new rules.

## Hard rules (verbatim)

UNKNOWN SCORE ≠ KNOWN 0–0. Never use home=0, away=0 as unknown.

Two yellow records must not synthesize a RED_CARD record. Second-caution awareness may be derived. Sending-off stays an explicit referee act.

MATCH and SHOOTOUT accounting are distinct. Shirt number is not identity.

Saved only after DurableCommitSuccess. RAM, queue, API, Bluetooth, cloud, and optimistic UI are not Saved.

Injury is OUTSIDE the drafted event set. FTM cannot keep a hidden legacy Injury writer. Decision required: hide/disable for FTM, or stop for an Injury contract. Do not choose.

## Draft acceptance criteria

Each row is a requirement to freeze later. None is accepted in this wave.

| Domain | Draft criterion | Parent evidence | Disposition |
| --- | --- | --- | --- |
| Match setup | Two stable teams, participant identity sufficient for the events actually captured, and a known Match Authority generation | Identity types are not in the parent vocabulary. Legacy phone setup still exists | UNRESOLVED |
| One writer | After Match Ready, exactly one writable Match Authority. The legacy aggregate is not a second writer for in-scope events | ADR-014 is frozen. `apps/referee_phone/lib/match/match_session.dart` and `capture_overlay.dart` still exist on the parent | NOT MET |
| Lifecycle | Enter field, match start, period start and end, suspension and resumption, and match end are projections of Match Records. A display threshold such as 45:00 does not by itself end a period | Parent temporal vocabulary and active-period elapsed projection exist. Enter-field is not a parent semantic code. PR #9 adds `REFEREE_ENTERED_FIELD_FOR_MATCH_START` off main; that code is not adopted here | UNRESOLVED |
| TIME | Exact time is shown only when continuity and authority allow it. Bounded or unresolved time is not rendered as one invented minute | Parent temporal projection. Not re-certified here | NOT ACCEPTED |
| Goal | The referee records a goal for the credited team. The score changes only after D1 | No `GOAL` code on the parent | DRAFT ONLY |
| Score | A numeral is current score only when coverage, authority, dependencies, and projection trust allow a known value | Score facet is untrusted and has no numeral | HOLD ON PARENT BEHAVIOR |
| Yellow | An administered caution becomes a Match Record. Identity and accounting scope are explicit | No `YELLOW_CARD` code on the parent | DRAFT ONLY |
| Cautions | "No caution" is shown only when disciplinary evidence is complete enough to prove the negative. Otherwise unavailable or unknown | No cautions recall in the new core | DRAFT ONLY |
| Red | Sending-off is an explicit referee act. Two yellow records do not create a red record | Parent vocabulary has no red. Legacy `docs/mvp-scope.md` already forbids second-yellow auto-red. That product line is not a new red contract | DRAFT ONLY |
| Substitution | Participant status changes when the substitution is complete, and only then | No substitution semantic on the parent. Legacy capture still has the event type | DRAFT ONLY |
| Corrections | Committed records are not edited or deleted in place. Correction and withdrawal are new records | `CORRECTION` and `LEGAL_SUPERSESSION` exist and do not create sporting state | PARTIAL ON PARENT, SPORTING EFFECT UNRESOLVED |
| Saved | No successful Saved without `DurableCommitSuccess` | `DurableCommitSuccess` is defined as the D1 success result. The port comment says test doubles must not return it | DRAFT ALIGNED WITH PORT, NOT CERTIFIED |
| Recovery | After process kill and reopen, only durably committed records rebuild as facts | Software D1 boundary exists. Power-loss survival is not claimed by the adapter | LOCAL GATE REQUIRED |
| Offline | After Match Ready, the active capture device finishes the match without network, cloud, or peer | ADR-012 | NOT RE-TESTED |
| Post-match | Score, discipline, and event history in the report come from Match Memory | Summary page on the parent is not a Match Memory report | NOT MET |
| Legacy remainder | Every event type without a new contract is either migrated or explicitly disabled | Injury, and on candidate phone branches also red and substitution, still have a legacy writer. See below | DECISION REQUIRED |
| Physical durability | A SQLite `COMMIT` return is not a power-loss certification | Adapter and `docs/local-gates.md` | LOCAL GATE REQUIRED. PHYSICAL DATA REQUIRED |

## Injury

Injury is OUTSIDE the drafted event set. FTM cannot keep a hidden legacy Injury writer. Decision required: hide/disable for FTM, or stop for an Injury contract. Do not choose.

Observed, not decided:

- Parent legacy `EventType` includes `injury` (`packages/match_core/lib/enums/enums.dart`).
- Parent Live Match still presents that type (`apps/referee_phone/lib/features/live_match/capture_overlay.dart`, `live_match_page.dart`).
- `docs/product.md` and `docs/mvp-scope.md` still list injuries inside the phone-complete match.
- On PR #10, goal and yellow are routed away from the legacy overlay. Red, substitution, and injury still reach `session.saveEvent`. That is evidence of a remaining legacy writer, not permission to keep it and not permission to delete it.

## Invariants

- Match Memory is the immutable record log. Projection is disposable.
- Exactly one writable Match Authority for a match during cutover.
- Saved only after DurableCommitSuccess. RAM, queue, API, Bluetooth, cloud, and optimistic UI are not Saved.
- UNKNOWN SCORE ≠ KNOWN 0–0. Never use home=0, away=0 as unknown.
- Two yellow records must not synthesize a RED_CARD record. Second-caution awareness may be derived. Sending-off stays an explicit referee act.
- MATCH and SHOOTOUT accounting are distinct. Shirt number is not identity.
- Replication, when it exists, exchanges records and does not use last-write-wins and does not transfer capture authority.
- Schema upgrade does not rewrite historical record meaning.
- A display clock is not temporal authority.

## Fail-closed modes

- Any in-scope capture whose durable commit does not return `DurableCommitSuccess` must not acknowledge Saved.
- A score facet without an accepted score-trust contract stays non-numeric, as on this parent.
- Incomplete disciplinary evidence must not be displayed as "no caution".
- Two yellow records must not append a red record.
- A second writer (legacy `MatchSession` or a second core) for an in-scope event fails the one-authority criterion.
- Network, cloud, Bluetooth, or phone reachability must not be required for match-critical capture after Match Ready on the autonomous device.
- Power-loss, hardware, and referee results that were not collected must stay uncertified.

## Minimum tests

These are the minimum tests a later implementation wave must name. They are not implemented by this draft, and a green suite on an older branch does not satisfy them.

- Goal for the home side and for the away side, then rebuild, with the numeral absent until `DurableCommitSuccess`.
- Known 0–0 only from an explicit trusted empty standing set. A missing score facet must not render `0–0`.
- Commit failure and retry: no Saved on failure; one standing goal after a successful retry of the same intent.
- Process kill after failed commit: the failed event does not reappear as Saved.
- Process kill after `DurableCommitSuccess`: the record rebuilds.
- Two yellow records, same participant, same MATCH scope: no `RED_CARD` record; second-caution awareness may be present.
- Same shirt number, two participant ids: cautions do not merge.
- MATCH caution absent from the SHOOTOUT ledger.
- Legal withdrawal of a goal: original record remains; standing score no longer counts it.
- Legacy injury path: either absent from the FTM UI or refused by the commit port. The choice is not made here, so the test cannot be written as a single expected button.
- Offline capture after Match Ready with network disabled.
- Report totals equal the rebuilt projection, not a legacy aggregate.

## Unresolved questions

- Founder: accept or reject the governance delta in `GOVERNANCE_DELTA.md`.
- Founder: hide/disable Injury for FTM, or stop for an Injury contract.
- Founder: whether "enter field" is inside FTM. PR #9 introduces `REFEREE_ENTERED_FIELD_FOR_MATCH_START` off this parent. This draft does not adopt that code.
- Match Authority: freeze the domain contracts linked from this file before any implementation wave.
- Match Authority: which remaining legacy event types besides Injury must be disabled together (red and substitution still write through the legacy session on PR #10).
- Engineering: whether the parent fail-closed score facet remains the only legal score surface until `SCORE_TRUST_CONTRACT.md` is frozen. This draft says yes as a hold, not as a new algorithm.
- Don: no referee protocol is accepted here. REFEREE DATA REQUIRED. HUMAN EVIDENCE ABSENT.
- Tony: no device protocol is accepted here. LOCAL GATE REQUIRED. PHYSICAL DATA REQUIRED. HARDWARE EVIDENCE ABSENT.

## Authority

Product scope: Founder / Product Command. Not issued.
Sporting meaning: Match Authority. Not issued.
D1 and projection: Engineering Architecture, inside the frozen ADR index. This draft does not amend that index.
Human factors: Don. Not issued.
Hardware: Tony. Not issued.
