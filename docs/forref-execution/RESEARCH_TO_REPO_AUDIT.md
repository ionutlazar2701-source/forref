# Research claims versus repository evidence

Audit date: 2026-10-18. Base inspected: `919c9062d607f0af255ad368b8c6cb2658d6c85a` (`main`, “Establish FORREF match authority and cloud execution foundation”).

The attached report `FORREF_DEVELOPMENT_RESEARCH.md` is an execution-planning input. It does not override `AGENTS.md` or `docs/architecture-authority.md`.

## Classification

| Claim | Class | Repository evidence |
| --- | --- | --- |
| Match Memory is immutable records; projection is disposable; D1 before Saved; no LWW | FROZEN CONTRACT | `docs/architecture-authority.md` ADR-001–018. Code: `packages/forref_match_core`, `packages/forref_match_persistence` |
| Phone is the product; watch is later; Flutter is not a watch client | FROZEN CONTRACT | `AGENTS.md`, `docs/mvp-scope.md`, `docs/platforms.md` |
| No second-yellow auto-red; match and shootout discipline stay distinct | FROZEN CONTRACT | `docs/mvp-scope.md` never-list. No shootout semantic in `V1SemanticTypeCode` |
| Visual design, including watch screens, is undecided | BLOCKED | `docs/open-decisions.md`: do not draw screens or adapt to watch until asked |
| Physical watch behavior cannot be certified in cloud | BLOCKED | `docs/local-gates.md`. Rental names in `docs/hardware-test-matrix.md` are candidates, not measurements |
| WATCH CORE 002D-1 at `fda5af6eb9013e6c37b4455d70fb8f811c4b3962`, tree `research/watch_core_r1` | RESEARCH INSTRUMENT, NOT MERGED | Object exists on PR #12 at fda5af6, not merged, static research instrument, no Match Record commits, no human study, no hardware certification. It is not an ancestor of `origin/main` or of `32eded4`. It is not production software and not an engineering PASS |
| 002D-1B evidence pack closed | VALIDATION PENDING | Report itself says pending. No pack in this repo. **EVIDENCE ACCESS HOLD** |
| Central Instrument A (`PHASE → TIME → SCORE → CAPTURE / CAUTIONS`) is the validation baseline | DESIGN / DOMAIN APPROVED as a baseline, not production UX | Stated in the research report and in this run’s charter. No watch UI implements it |
| Candidate C Score Sidecar | RESEARCH PROTOTYPE — absent | No C screens, no prototype path |
| Production Capture Foundation frozen | HOLD | Not frozen. Logical names (`CaptureInteractionContract`, `ScoreTrustState`, …) are not types in this repo |
| Goal / Yellow / Red / Substitution as parallel watch packages | HOLD | New core vocabulary is temporal plus correction/supersession only. Legacy `packages/match_core` has mutable goal/card/sub events and must not gain new authority |
| Score facet can show a confirmed numeral | IMPLEMENTED BUT UNVERIFIED — actually fail-closed | `ProjectionFacet.score` exists. `MatchProjectionState` has no home/away integers. Production resolver leaves score `untrusted` without explicit semantics. This wave locked that with tests. No freshness/completeness contract |
| Disciplinary facet is a cautions read model | IMPLEMENTED BUT UNVERIFIED — fail-closed | Facet id exists. v1 records do not trust it. No CAUTIONS recall surface in the new core |
| Active-period elapsed is display, not period-end authority | IMPLEMENTED AND VERIFIED | `ActivePeriodElapsedProjection.regulationDisplayThreshold` is 45:00 display-only. This wave’s attacks did not produce a false exact elapsed or a false period end on reachable inputs. `certified` on evidence is not hardware certification |
| Legacy two yellows become a red | RESEARCH PROTOTYPE claim not observed | `EventReducer.applyNewEvent` of two `yellowCard` events leaves two yellows and score 0–0 |
| `./tool/verify_cloud.sh` certifies phone + new core + persistence | IMPLEMENTED AND VERIFIED on this integration branch | Passed after the wave (see `INTEGRATION_REPORT.md`). It does not run `packages/match_core` or `research/**` |
| Garmin / Wear OS / watchOS input models differ | DESIGN / DOMAIN APPROVED as a constraint | Cited in the research report. No platform watch client exists here to verify |

## Discrepancies

1. This repository’s HEAD is a phone Match Core foundation. The object `research/watch_core_r1` at `fda5af6eb9013e6c37b4455d70fb8f811c4b3962` exists on PR #12 at fda5af6, not merged, static research instrument, no Match Record commits, no human study, no hardware certification. It is not the starting SHA of this branch.
2. “Foundation can be drafted in parallel” is not permission to publish Goal/Yellow/Red/Sub semantics. Those domain contracts are absent, so implementation stops at **DOMAIN CONTRACT REQUIRED**.
3. Legacy phone capture (`apps/referee_phone/lib/features/live_match/capture_overlay.dart`) is not Watch Live Core.
4. A green cloud suite is not physical-device, power-loss, or referee-study evidence.
5. The report’s parallel event wave (four agents on Goal/Yellow/Red/Sub) is not safe on this HEAD.

## What was not treated as done

Missing watch product code and missing event contracts were not filled in by assumption. The 002D tree was not copied into this HEAD. Object exists on PR #12 at fda5af6, not merged, static research instrument, no Match Record commits, no human study, no hardware certification.
