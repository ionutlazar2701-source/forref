# FORREF — NIGHT PROGRAM PHASE II HANDOFF

FINISH THE BANKS → BUILD THE BRIDGES

PROGRAM STATUS: PASS

START EVIDENCE SHA: `f4bf48ffd397b1cd81cf2f40a08084aa49561b7e`

EXECUTION BASE SHA: `f4bf48ffd397b1cd81cf2f40a08084aa49561b7e`

FINAL PRODUCTION SHA: `39a676b25682e2b6930b6d4f7f02340b55ae01a8`

The evidence tip that records this handoff is the commit that adds this file. Read it with `git rev-parse HEAD` on `cursor/forref-night-phase2-30fd` after that commit.

BRANCH: `cursor/forref-night-phase2-30fd`

## BANK G — team-official identity

STATUS: PASS

SHA: `87f8cce1e031b152614c9dc08fdae5d44152eb82`

IMPLEMENTED: `MatchTeamOfficialId`, `MatchScopedTeamOfficialId`, `TeamOfficialTeamBinding`, and the sealed `DisciplinarySubjectRef` with participant and team-official cases. Equality includes subject kind. Display name, role label, and bench position are not the id.

SABOTEUR: PASS

## BANK B2 — Yellow v2 / team-official Yellow

STATUS: PASS

SHA: `0ff1ae4ec7cafac6d3d4e48347811dda07885ce8`

V1 HISTORICAL COMPATIBILITY: PASS. Stored v1 stays participant-only and is normalized at read time.

TEAM-OFFICIAL YELLOW: PASS. Payload schema 2 only, admitted when one trusted team binding exists.

IDEMPOTENCY: PASS. Same intent and same meaning succeeds. A different subject kind, official, or scope conflicts. No proximity deduplication.

SABOTEUR: PASS

## BANK D — SEND_OFF

STATUS: PASS

SHA: `65cd62f94f4637541c6524f27e6f0024c50fbb15`

DIRECT: PASS. No yellow ids.

SECOND_CAUTION: PASS. Named Y1 and Y2 plus `CausalDependency` for each. Match id of Y1 and Y2 must equal the SEND_OFF match id (`39a676b25682e2b6930b6d4f7f02340b55ae01a8`).

TWO YELLOW → AUTO SEND_OFF: ABSENT

DEPENDENCY VALIDATION: PASS

CORRECTION / SUPERSESSION: PASS. A later yellow supersession does not delete SEND_OFF history. Legal effect of the SEND_OFF changes only through its own correction or supersession.

SABOTEUR: PASS

## BANK E — substitution

STATUS: PASS

SHA: `02a8e5737023a05f90126201ef485274e4d6d3f6`

COMPLETED TRANSITION: PASS

TEAM PROOF: PASS. OUT and IN need one trusted binding, the same team, and `payload.teamId`.

STATUS PROJECTION: PASS. OUT projects substituted. IN projects on field.

RETURN-SUBSTITUTION SAFETY: PASS. The same participant id can later project on field. Status is not a new id.

NO COMPETITION ENGINE: PASS. A missing competition profile does not reject a completed transition.

SABOTEUR: PASS

## STATUS ↔ AWARENESS

STATUS: PASS

SHA: `eab493e9392da518c142255c0cc2a258ea53b5ec`

ONE PROOF ENGINE: PASS. `validateAuthoritativeHistoryCompleteness` is the shared walk. `ScoreCompletenessProof` remains the score adapter.

PARTICIPANT HISTORY CONTINUITY: PASS. Substitution does not reset the yellow ledger.

TEAM-OFFICIAL AWARENESS: PASS. Same evaluator.

UNKNOWN ≠ NO: PASS

## AWARENESS ↔ SEND_OFF

STATUS: PASS

SHA: `39a676b25682e2b6930b6d4f7f02340b55ae01a8`

The first bridge commit is `47d0b91ae5a730b1b8357e2729dfcbc3a56cbfe3`. The saboteur then required two match-scope repairs, recorded in [PHASE2_ADVERSARIAL_REPORT.md](PHASE2_ADVERSARIAL_REPORT.md).

NO AUTO SEND_OFF: PASS

ACTIVE COLLECTION: PASS. An effective explicit SEND_OFF in this match, for this subject and scope, clears `activeCautionSurface`.

HISTORICAL CAUTIONS PRESERVED: PASS

## Cross-domain saboteur

RESULT: PASS

REVIEWER: Grok `bc-b4ae2960-049d-5a4d-921d-b09ea16902a0`

PRODUCTION CODE EDITS BY REVIEWER: NONE

NEW ATTACKS: cross-match SEND_OFF must not close this match's surface. Cross-match yellows must not complete this match's second-caution dependency. Both failed once, were repaired, and passed on the third review.

## Test evidence

Match Core: 347 passed. Analyzer: no issues.

Persistence: 88 passed. Analyzer: no issues.

Phone: 125 passed. Analyzer: no issues.

verify_cloud: PASS. Exit 0. Core 347, persistence 88, phone 125. The run is `./tool/verify_cloud.sh` on production `39a676b25682e2b6930b6d4f7f02340b55ae01a8` before this documentation commit. Git stores `tool/verify_cloud.sh` and `tool/cloud_bootstrap.sh` as mode 644. The passing run set the executable bit in the workspace only. An earlier invocation exited 1 because `cloud_bootstrap.sh` was not executable; every analyze and test step in that invocation had already passed with the same counts.

CI: NOT CLAIMED

Hardware certification: NOT CLAIMED

Human validation: NOT CLAIMED

## One writable authority

Goal: PASS, unchanged

Yellow phone cutover: NOT MIGRATED

SEND_OFF phone cutover: NOT MIGRATED

Substitution phone cutover: NOT MIGRATED

Injury: UNAVAILABLE

## Foundation deltas

NONE

## Domain deltas

NONE

## Product UX deltas

PHONE PRODUCT / UX GATE REQUIRED

Remaining interaction questions:

1. How the referee selects a `MatchParticipantId` or a `MatchTeamOfficialId` before an authoritative Yellow, SEND_OFF, or substitution. The current overlay still uses a squad list, unknown, or a shirt number.
2. RO and EN copy for awareness unavailable, awareness conflicted, and an active surface closed by an explicit SEND_OFF.
3. How a second-caution situation is shown without a control that writes SEND_OFF by itself.
4. How the referee names OUT, IN, and team for a completed substitution without a competition-rules screen.
5. Visual design for those surfaces is still an open decision and was not invented here.

## Local gates

Still open: physical D1 power loss, real-device storage, platform restart and background, watch lifecycle, battery, physical watch reliability, human referee validation.

LOCAL GATE REQUIRED. HARDWARE EVIDENCE ABSENT. HUMAN EVIDENCE ABSENT.

## Phone cutover status

HOLD

## Next product command decision

A. PHASE II ACCEPT — BEGIN PHONE PRODUCT/UX AUTHORITY GATE

Băncile de identitate a oficialului de echipă, cartonaș galben v2, trimitere explicită de pe teren și schimbare încheiată stau, iar podurile de conștientizare folosesc același motor de probă. Telefonul nu a fost mutat pe aceste scrieri. Următorul pas este poarta de produs: cum alege arbitrul identitatea, cum vede o situație necunoscută, și cum confirmă o trimitere sau o schimbare pe care chiar a aplicat-o. Nu se taie încă autoritatea de pe telefon.
