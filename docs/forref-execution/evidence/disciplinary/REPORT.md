# Disciplinary authority gap

Actual model: Grok 4.7 (session identity). Requested preference: `grok-4.7-high`. Cloud run metadata `originalModelName` was null, so no separate high-tier id was returned.

This is not production disciplinary approval.

**DOMAIN CONTRACT REQUIRED** before any Yellow, Red, or Substitution implementation.

There is no frozen Yellow/Red Minimum Irreversible Truth in this repository. These tests do not invent caution, dismissal, sending-off, or recall rules.

## New core

`packages/forref_match_core` production `V1SemanticTypeCode` values do not include `GOAL`, `YELLOW`, `RED`, `SUBSTITUTION`, or `SHOOTOUT`.

`ProjectionFacet.disciplinary` exists. Projecting each committed v1 semantic with `ProductionSemanticsResolver` and `DeterministicMatchProjector` leaves disciplinary `ProjectionTrust.untrusted`. A committed temporal record does not make disciplinary trusted. A complete temporal correction of `MATCH_STARTED` still leaves disciplinary untrusted.

Structured payloads whose `semanticType` is `YELLOW`, `RED`, `SECOND_YELLOW`, or `SHOOTOUT_CAUTION` stay unsupported. Their projections leave disciplinary untrusted. Two `YELLOW` payloads stay two unsupported records.

Shootout scope is **ABSENT**, not implemented as a distinct disciplinary scope. `SHOOTOUT_CAUTION` does not parse as a v1 code and does not collapse into `MATCH_ENDED`. `penaltyShootOutAfterMatchEnd` does not add a disciplinary facet and does not create a `shootout` projection facet.

**CAUTIONS recall does not exist in the new core.** `research/live_core_a` marks the recall instrument unavailable. That research package is not Match Core.

## Legacy

`packages/match_core` `EventType.yellowCard` and `EventType.redCard` are separate events. `EventReducer.applyNewEvent` appends the supplied event. `ScoreCalculator` counts goals only. Applying two yellow cards for the same player does not append a red card and does not change the score. No automatic red was observed in current legacy code. Legacy stays mutable and gained no new semantics.

Legacy phone capture (`apps/referee_phone/lib/features/live_match/capture_overlay.dart`) is not watch Live Core.

## Gates

- No Yellow, Red, Goal, or Substitution workflow was implemented.
- No enum values were added.
- No `lib/`, phone app, persistence, pubspec, or `tool/` edits.

## HOLD

None on source inspection. The locking tests are the proof. If two yellows append a red, that test is the defect record and legacy `lib/` stays unchanged.
