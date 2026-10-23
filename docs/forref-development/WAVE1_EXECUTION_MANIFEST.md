# WAVE 1 execution manifest

Accepted Foundation SHA: `5772671a9674e00c372268047d5f54073610af22`.

Execution base: the documentation commit that introduces this file on `cursor/forref-wave1-goal-score-30fd`. Implementation stages descend from that commit. They do not descend from `origin/main`, `32eded4`, or a historical Goal branch.

Repository drift at launch: none. HEAD was the accepted SHA and the work tree was clean.

## Current file map

Match Core already has immutable records, `MAIN_REFEREE` authority, generation, correction and legal-supersession relationships, a deterministic projector with a score facet that stays untrusted, and SQLite D1 (`journal_mode=DELETE`, `synchronous=FULL`). It has no GOAL semantic and no `MatchTeamId`.

The phone still records legacy `EventType` events, including goal, through `CaptureOverlay` and `MatchSession`. `new_match.dart` stores `Score(home: 0, away: 0)`.

## Authority definition for implementation

These five responsibilities are the public budget. A sixth independent subsystem is SIMPLICITY DELTA REQUIRED.

1. `MatchTeamId` plus a match-scoped binding. The id is an opaque non-empty string. It is not HOME, AWAY, a display slot, or a team name.
2. `V1SemanticTypeCode.goal` and `GoalPayload`. RecordKind `humanDetermination`. Required sporting field: `scoringTeamId`. Technical field: `captureIntentId`. `temporalContext` is optional and is not part of the irreversible sporting payload.
3. Pure capture-intent identity. Key is `(matchId, MAIN_REFEREE, captureIntentId)`. The bound meaning is GOAL, principal id, generation, and `scoringTeamId`. Same meaning is idempotent. A different team or semantic is an idempotency conflict. No time-based dedup. Durable admission is persistence, not a second database.
4. Effective Goal resolution through the existing `CorrectionTarget` and `LegalSupersessionTarget` links. A Goal correction carries the repaired `scoringTeamId` on the existing correction semantic. Legal supersession removes or restores that same Goal's scoring effect. No Goal-specific graph engine.
5. `ScoreProjection` with exactly `KnownScore`, `ScoreUnavailable`, and `ScoreConflicted`. Integers exist only on `KnownScore`, keyed by `MatchTeamId`. Zero rows, an empty database, missing sequence, unsupported score-affecting semantics, a missing score-affecting dependency, or a failed integrity check is `ScoreUnavailable`. Contradictory complete branches are `ScoreConflicted`. Known 0–0 requires the positive generation-1 completeness proof, including zero effective Goals.

Generation-1 authority root is a value that says generation is 1, names the principal and device, and has no predecessor. No generation 2 and no transfer.

## Ownership

| Stage | Owner | May edit | Must not edit |
| --- | --- | --- | --- |
| 1 Core | one Composer agent | `packages/forref_match_core/lib/**`, `packages/forref_match_core/test/**` | persistence pragmas, phone `lib/`, root pubspec, prohibited domains |
| 2 Persistence | one Composer agent, after Stage 1 SHA | `packages/forref_match_persistence/**` | phone UI, a second store, `journal_mode`, `synchronous` |
| 3 Phone | one Composer agent, after Stage 2 SHA | phone application and Live Match Goal/score surfaces | Yellow, Red, Substitution, Injury writers; visual redesign; participant registry |
| 4 Tests | same owners, evidence in `docs/forref-development/WAVE1_TEST_MATRIX.md` | tests for the 24 obligations | production invariants |
| 5 Verify | orchestrator | none required | — |
| 6 Saboteur | Grok, not the implementation agent | isolated tests only | implementation rewritten to pass its own review |

## Integration order

Stage 1, then Stage 2, then Stage 3, then the 24-obligation matrix, then `./tool/verify_cloud.sh`, then the saboteur.

## STOP conditions

FOUNDATION DELTA REQUIRED if Goal needs a scorer, HOME/AWAY as identity, a second score store, network for Saved, or authority transfer.

PRODUCT UX DELTA REQUIRED if the current Goal taps cannot emit a stable team id without a new participant decision, or if the score widget cannot show unavailable or conflicted without a new presentation decision. Do not restore the legacy Goal writer to avoid that stop.

SIMPLICITY DELTA REQUIRED if a new public concept appears beyond the five responsibilities above.
