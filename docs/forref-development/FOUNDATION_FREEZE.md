# Foundation Freeze

Canonical contract summary for implementation agents.

This file is the single Foundation Freeze statement. Historical drafts in this directory are not a second canonical pack. [WAVE1_GOAL_SCORE_CONTRACT.md](WAVE1_GOAL_SCORE_CONTRACT.md) is the bounded contract a future WAVE 1 agent consumes. [FUTURE_AUTHORITY_TRANSFER_CONTRACT.md](FUTURE_AUTHORITY_TRANSFER_CONTRACT.md) is documentation only.

DOMAIN: FROZEN

ARCHITECTURE: FROZEN CANDIDATE

RELIABILITY: FROZEN CANDIDATE

SIMPLICITY: FROZEN CANDIDATE

PRODUCT COMMAND: PENDING FINAL ACCEPTANCE

WAVE 1: HOLD — AWAITING FOUNDATION FREEZE SHA ACCEPTANCE

This document does not implement Goal or Score. It does not authorize WAVE 1. It does not certify hardware, referees, or power-loss durability.

## Domain freeze

Authoritative Goal means the MAIN_REFEREE has awarded one goal to a known stable match-team identity.

Minimum Irreversible Truth:

- referee award/acceptance;
- scoring team identity.

Not required for Goal authority: scorer identity, participant identity, own-goal classification, exact match minute, reporting classification.

Own goal is attribution or classification of the same Goal occurrence. It is not a second Goal occurrence.

Score is derived from currently effective authoritative Goals. Score is not an independent sporting occurrence.

YELLOW_CARD means a caution that has been authoritatively administered to an identified eligible disciplinary subject. Intention is not Yellow Card authority.

Two standing Yellow Cards may create factual awareness. They must not automatically create authoritative SEND_OFF.

Direct sending-off and second-caution sending-off remain distinct disciplinary pathways.

A completed substitution requires identified outgoing and incoming participants and lawful entry of the incoming substitute.

MATCH and SHOOTOUT caution scopes are separate.

CORRECTION repairs FORREF's stored description of unchanged real-world truth.

LEGAL SUPERSESSION / reassignment changes current referee-authoritative legal effect.

History remains immutable.

Injury is out of FTM v1. FTM v1 has no authoritative Injury capture.

## Architecture freeze

FA-01. Stable MatchTeamId. Goal may not use HOME/AWAY, a display label, or a team name as canonical identity.

FA-02. GOAL V1. RecordKind HUMAN_DETERMINATION. Authority MAIN_REFEREE. Minimum sporting payload: scoringTeamId. Technical idempotency: captureIntentId. temporalContext is optional.

FA-03. Fail-closed ScoreProjection states: KnownScore, ScoreUnavailable, ScoreConflicted. A numeric score exists only in KnownScore.

FA-04. Known score requires positive score-completeness proof. UNKNOWN SCORE ≠ KNOWN 0–0.

FA-05. Goal legal effect uses immutable CORRECTION and LEGAL_SUPERSESSION relationships.

FA-06. Future participant identity uses stable MatchParticipantId. Status and shirt number are not identity. Implementation is deferred.

FA-07. The Yellow/Cautions frontier preserves standing versus historical, MATCH versus SHOOTOUT, identity trust, collection completeness, and no automatic SEND_OFF. Implementation is deferred.

FA-08. Substitution preparation is a non-authoritative local workflow. A completed substitution becomes Match Memory authority only after the lawful participant transition.

FA-09. The referee field-entry disciplinary boundary is separate from MATCH_STARTED and PERIOD_STARTED. Implementation is deferred from WAVE 1.

FA-10. Exactly one match authority mode: LEGACY_ONLY xor MATCH_MEMORY. Never both writable.

FA-11. Goal extends schema-v1 semantics without rewriting historical semantics. Canonical equality must include every authoritative Goal field.

FA-12. D1 precedes Saved. Projection refresh does not gate Saved.

FA-13. Capture authority has a durable authority-control root. MATCH READY is derived admission, not sporting truth.

FA-14. FTM Injury capture is unavailable.

FA-15. Match Core remains device-neutral. The phone is not encoded as permanent sporting authority.

## Reliability freeze

F-R2. CaptureIntentKey is `(matchId, authorityScope, captureIntentId)`. One key permanently binds one immutable command meaning: semanticType, authorityPrincipalId, authorityGeneration, and the canonical irreversible sporting payload. For Goal that payload is GOAL plus scoringTeamId. One key creates at most one authoritative outcome. The same intent and the same command are an idempotent existing success. The same intent and a different team or semantic are an idempotency conflict. No timestamp or temporal-proximity deduplication.

F-R3 / F-R4. KnownScore requires positive proof across match authority mode, authority root, authorized origin/generation coverage, sequence continuity, record integrity, semantic support, correction dependencies, supersession dependencies, authority conflict, relationship conflict, resolved team identity, and a deterministic effective Goal set. Initial KnownScore(0–0) requires positive generation-1 bootstrap and a complete verified authority history. Zero Goal rows alone prove nothing.

F-R5. Generation number alone is not fencing. The future transfer contract is [FUTURE_AUTHORITY_TRANSFER_CONTRACT.md](FUTURE_AUTHORITY_TRANSFER_CONTRACT.md). WAVE 1 does not implement transfer.

F-R6. MATCH READY is historical derived admission. It is not permanent write permission. Immediately before a Goal commit, current operation eligibility must still establish MATCH_MEMORY mode, valid team binding, MAIN_REFEREE authority, the current active device, the current generation, no unresolved transfer or fencing state, semantic support, a writable healthy D1 path, a usable integrity mechanism, and no authoritative lifecycle prohibition. Temporal precision degradation alone must not block a valid Goal.

F-R7. One generic correction and legal-supersession resolver handles missing targets, late targets, semantic compatibility, correction chains, supersession chains, correction plus supersession, competing relationships, cycles, reversal, and transport-order independence. A missing score-affecting dependency yields ScoreUnavailable. Contradictory complete branches yield ScoreConflicted. Arrival timestamp never determines authority.

F-R10. Bytes present are not a valid authoritative Match Record. A trusted effect requires valid framing, decoding, identity, schema, payload, authority envelope, integrity evidence, and origin-slot uniqueness. Integrity evidence binds authoritative record content. Corrupt evidence is preserved or quarantined. It is not silently deleted.

F-R12. Keep separate: historical record validity, authoritative-history completeness, current capture authority, and permission to append future records. Historical truth does not grant future write authority. Loss of the current authority root does not erase independently valid Goals. It may make the score unavailable when completeness cannot be proven. It blocks new authoritative capture. It does not allow silent generation-1 recreation.

## Simplicity scope

FD-01. Score completeness is a derived proof obligation using existing projection trust, authority, coverage, dependencies, origin sequence, semantic support, and conflict machinery. Do not create a second persistent Score completeness subsystem.

FD-02. A future WAVE 1 implements only a durable generation-1 MAIN_REFEREE capture-authority root on the phone. It does not implement generation transfer, federation, distributed leases, quorum, device election, or watch synchronization. Future transfer semantics may be documented only.

FD-03. A future WAVE 1 implements no participant identity system, disciplinary projection, substitution machinery, field-entry implementation, or post-match exit implementation. Those frozen contracts remain future-wave constraints.

Maximum conceptual budget for that future wave:

1. stable team identity;
2. durable Goal capture;
3. correction and legal supersession;
4. proven-complete score;
5. match authority admission and legacy isolation.

Do not introduce another independent infrastructure subsystem unless a frozen invariant demonstrably cannot be satisfied otherwise.

## WAVE 1 boundary

WAVE 1 is not authorized by this file.

If Product Command later accepts this freeze SHA, the allowed surfaces are listed in [WAVE1_GOAL_SCORE_CONTRACT.md](WAVE1_GOAL_SCORE_CONTRACT.md). No visual redesign is included.

## Prohibited scope

Hold, including after a future WAVE 1 start:

Yellow implementation. Cautions Recall implementation. Red / SEND_OFF implementation. Automatic second-caution dismissal. Substitution implementation. Injury implementation. Participant registry. Broad roster architecture. Referee field-entry implementation. Autonomous watch capture. Watch UI. Central Instrument A production UI. Watch synchronization. Bluetooth replication. Cloud replication. Authority transfer workflow. Generation 2+ implementation. Distributed federation. Leases, quorum, or election. Added-time authority expansion. A new visual system. Hardware certification. Human-factors certification. Monetization.

## Later gates

LOCAL GATE REQUIRED, and not claimed here:

- real power-loss D1;
- real-device SQLite or storage behavior;
- platform restart and background behavior;
- watch process lifecycle;
- battery;
- physical watch reliability;
- human referee trials.

No watch platform or device is production-certified by this freeze.

## Governance

The device operating model in `AGENTS.md` is the repository operating statement. Build order is sequencing. It does not encode the phone as permanent sporting authority.

WAVE 0E aligned these active instructions with this operating model:

- `.cursor/rules/product-context.mdc`
- `docs/platforms.md`
- `docs/product.md`
- `docs/mvp-scope.md`

`docs/architecture-authority.md` was not edited. ADR-001 through ADR-018 stay in force. Product Command acceptance of the freeze SHA is still pending. WAVE 1 stays HOLD. WAVE 0F is a governance reconciliation candidate and does not change this freeze. The occurrence classification is [WAVE0F_GOVERNANCE.md](WAVE0F_GOVERNANCE.md). The WAVE 0E classification remains [WAVE0E_GOVERNANCE.md](WAVE0E_GOVERNANCE.md).
