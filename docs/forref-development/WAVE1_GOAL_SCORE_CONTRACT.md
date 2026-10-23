# WAVE 1 Goal and Score contract

Bounded contract for a future WAVE 1 implementation agent.

WAVE 1: LAUNCH NOW / IN EXECUTION

Product Command accepted Foundation Freeze SHA `5772671a9674e00c372268047d5f54073610af22`. This file remains the bounded Goal and Score contract. It is not an implementation design. The status lines below record that acceptance. They do not change the sporting rules.

Canonical summary: [FOUNDATION_FREEZE.md](FOUNDATION_FREEZE.md).

DOMAIN: FROZEN

ARCHITECTURE: FROZEN CANDIDATE

RELIABILITY: FROZEN CANDIDATE

SIMPLICITY: FROZEN CANDIDATE

PRODUCT COMMAND: FOUNDATION FREEZE ACCEPTED

## Goal V1

Authoritative Goal means the MAIN_REFEREE has awarded one goal to a known stable match-team identity.

RecordKind: HUMAN_DETERMINATION.

Authority: MAIN_REFEREE.

Minimum sporting payload: `scoringTeamId`, a stable MatchTeamId.

Technical idempotency: `captureIntentId`.

`temporalContext` is optional. Temporal precision degradation alone does not remove Goal authority.

Not required for Goal authority: scorer identity, participant identity, own-goal classification, exact match minute, reporting classification.

Own goal is attribution or classification of that same Goal occurrence. It is not a second Goal record.

FA-01. `scoringTeamId` is not HOME, AWAY, a display label, or a team name.

FA-11. Goal extends schema-v1 semantics. It does not rewrite historical record meaning. Canonical equality includes every authoritative Goal field.

## Capture intent

CaptureIntentKey is `(matchId, authorityScope, captureIntentId)`.

One key permanently binds one command meaning:

- semanticType;
- authorityPrincipalId;
- authorityGeneration;
- canonical irreversible sporting payload.

For Goal the sporting payload in that meaning is GOAL plus `scoringTeamId`.

One key creates at most one authoritative outcome.

Same intent and same command: idempotent existing success.

Same intent and a different team or semantic: idempotency conflict.

No timestamp deduplication. No temporal-proximity deduplication.

## D1 and Saved

D1 precedes Saved.

Saved is `DurableCommitSuccess` only.

Saved is not RAM, a queue, API acceptance, Bluetooth sent, phone received, cloud accepted, optimistic UI, or a projection refresh.

Projection refresh does not gate Saved.

## ScoreProjection

States:

- KnownScore
- ScoreUnavailable
- ScoreConflicted

A numeric score exists only inside KnownScore.

Score is derived from the currently effective authoritative Goal set. It is not its own sporting occurrence.

UNKNOWN SCORE ≠ KNOWN 0–0.

Do not use `home = 0` and `away = 0` as the representation of unknown, empty, incomplete, or conflicted.

## Positive completeness proof

KnownScore requires positive proof across:

- match authority mode;
- authority root;
- authorized origin and generation coverage;
- sequence continuity;
- record integrity;
- semantic support;
- correction dependencies;
- supersession dependencies;
- authority conflict;
- relationship conflict;
- resolved team identity;
- a deterministic effective Goal set.

Score completeness uses the existing projection trust, authority, coverage, dependency, origin sequence, semantic support, and conflict machinery. It is not a second persistent subsystem.

Zero Goal rows alone do not prove KnownScore(0–0).

## 0–0 bootstrap

Initial KnownScore(0–0) requires positive generation-1 bootstrap and a complete verified authority history.

An empty database must not yield KnownScore(0–0).

A valid complete bootstrap may yield KnownScore(0–0).

## Correction and supersession

Use one generic resolver for CORRECTION and LEGAL_SUPERSESSION.

It handles missing targets, late targets, semantic compatibility, correction chains, supersession chains, correction plus supersession, competing relationships, cycles, reversal, and transport-order independence.

CORRECTION repairs the stored description of unchanged real-world truth.

LEGAL SUPERSESSION changes current referee-authoritative legal effect.

History stays immutable. Arrival timestamp does not determine authority.

A missing score-affecting dependency yields ScoreUnavailable.

Contradictory complete branches yield ScoreConflicted.

## Integrity

Bytes present are not a valid authoritative Match Record.

Trusted effect requires valid framing, decoding, identity, schema, payload, authority envelope, integrity evidence, and origin-slot uniqueness.

Integrity evidence binds authoritative record content.

Corrupt evidence is preserved or quarantined. It is not silently deleted.

A duplicate recordId with different canonical content is a conflict, not a silent overwrite.

A duplicate origin slot is a conflict.

## Authority mode and generation-1 root

Exactly one writable mode: LEGACY_ONLY xor MATCH_MEMORY.

WAVE 1, when authorized, implements only a durable generation-1 MAIN_REFEREE capture-authority root on the phone.

MATCH READY is derived admission. It is not sporting truth and it is not permanent write permission.

Loss of the current authority root does not erase independently valid Goals, does not permit silent recreation of generation 1, may make the score unavailable, and blocks new authoritative capture.

## Current Goal admission

Immediately before Goal commit, eligibility still requires:

- MATCH_MEMORY mode;
- valid team binding;
- MAIN_REFEREE authority;
- current active device;
- current generation;
- no unresolved transfer or fencing state;
- semantic support;
- a writable healthy D1 path;
- a usable integrity mechanism;
- no authoritative lifecycle prohibition.

Temporal precision degradation alone must not block a valid Goal.

Field-entry implementation is not part of WAVE 1. The field-entry boundary stays separate from MATCH_STARTED and PERIOD_STARTED.

## Legacy isolation

The new Goal action must not write the legacy mutable aggregate.

Legacy Goal writes for that action are excluded.

Red, Substitution, Yellow, and Injury are not migrated by this contract. Injury capture is unavailable in FTM v1. Those paths must not become a second writer for Goal.

## Allowed surfaces, after acceptance only

`forref_match_core`: minimum MatchTeamId and team binding; GOAL semantic; Goal payload; capture-intent semantics; typed Goal correction; effective Goal resolution through existing relationship machinery; ScoreProjection; derived score completeness; generation-1 authority-root primitives only where required.

`forref_match_persistence`: Goal encode and decode; typed correction encode and decode; canonical equality; capture-intent uniqueness and admission; non-vacuous integrity binding; generation-1 authority-root persistence.

Phone application boundary: Goal admission; D1 commit; idempotent retry and recovery; MATCH_MEMORY Goal writer; legacy Goal writer exclusion; score rebuild from Match Memory; current Goal-operation eligibility.

Phone presentation: KnownScore, ScoreUnavailable, ScoreConflicted, and Goal history. No visual redesign.

## Prohibited in WAVE 1

Yellow. Cautions Recall. Red and SEND_OFF. Automatic second-caution dismissal. Substitution. Injury. Participant registry. Broad roster architecture. Referee field-entry implementation. Post-match exit implementation. Autonomous watch capture. Watch UI. Central Instrument A production UI. Watch synchronization. Bluetooth replication. Cloud replication. Authority transfer. Generation 2+. Federation, leases, quorum, or election. Added-time authority expansion. A new visual system. Hardware certification. Human-factors certification. Monetization.

## Test obligations

These tests are required evidence for a future WAVE 1. None of them is executed by the Foundation Freeze. Do not mark any of them TEST EXECUTED until WAVE 1 runs them.

1. Crash before, during, and after D1 commit.
2. Ambiguous ACK recovery.
3. Same-intent retry.
4. Concurrent duplicate capture.
5. Conflicting intent payload.
6. Empty database cannot yield Known 0–0.
7. Valid complete bootstrap yields Known 0–0.
8. Missing origin sequence yields an unavailable score.
9. An unsupported, potentially score-affecting semantic yields an unavailable score.
10. Correction with a missing target.
11. Competing corrections.
12. Goal legal supersession.
13. Supersession reversal.
14. Cycle detection.
15. Transport-order permutation equivalence.
16. Integrity mismatch.
17. Duplicate recordId with different canonical content.
18. Duplicate origin-slot conflict.
19. Corrupt or missing generation-1 authority root.
20. MATCH READY followed by storage failure.
21. Stale capture authority.
22. Projection failure after a successful Goal D1.
23. Temporal degradation without loss of Goal authority.
24. Rejection of mixed legacy and MATCH_MEMORY authority.

## Local gates

LOCAL GATE REQUIRED and not part of this contract's software proof: real power-loss D1, real-device storage behavior, platform restart and background behavior, watch process lifecycle, battery, physical watch reliability, and human referee trials.
