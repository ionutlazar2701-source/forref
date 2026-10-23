# FORREF S2.5R — Match Report discipline and substitution

Parent: S2.5 Product Operations · Goal baseline S2.5G (`aa4cb9dc`).

## Product model (shared with Goal)

Referee interaction → unfinished selection → review → frozen command → simulated commit → established research truth → presentation projection → **Match Report**.

Only **simulated saved** outcomes appear in Match Report. Known failure, unknown, selection, and frozen-unresolved commands do not.

## Flows

| Operation | Watch route | Report kind |
| --- | --- | --- |
| Goal (S2.5G) | `goalFlow` | `goal` |
| Yellow | `yellowFlow` | `yellow` |
| Direct send-off | `sendOffFlow` + direct offer | `directSendOff` |
| Second-caution send-off | `sendOffFlow` (successor required) | `secondCautionSendOff` |
| Substitution | `substitutionFlow` | `substitution` |

Second yellow **does not** create a send-off. Send-off after two cautions requires a **new** deliberate second-caution send-off action.

## Match time

All final actions capture `formatResearchMatchTime(matchElapsedSeconds)` at activation. Time is stored on `SavedCaution`, `SavedSendOff`, `SavedSubstitution`, and `SavedGoal`. Later clock advances do not rewrite established labels.

**LIVE TIMER CONTINUITY STILL RESEARCH LIMITATION** — clock advances via `AdvanceMatchClockIntent`; no continuous real-time tick.

## Match Report projection

`research/simulator_hf_bridge` builds entries from established rows sorted by shared `_reportSequence`. Seeded cautions without sequence/time are excluded (`reportable`).

Presentation labels: `matchReportKindLabel()` in `simulator_presentation`.

## Failure semantics

- **SIMULATED SAVED — not production D1** → report entry
- **NOT SAVED — known simulated failure** → no entry
- **SAVE NOT VERIFIED** → no established report entry

## Tests

- `research/hf_prototype/test/s2_5r_match_report_operations_test.dart` — Y/R/S/SUB matrices, combined chronology, pollution, founder-style watch journey
- Existing S2.5G goal tests remain in `s2_5g_goal_match_report_test.dart`

## Windows Founder gate (one session)

```text
git switch cursor/forref-simulator-s2-5-product-operations
cd research/hf_prototype
flutter pub get && flutter analyze && flutter test
flutter run -d windows
```

Scenario: `s21MatchReportOps` roster (#9 Popescu, #6 Ionescu, #4 Matei, #17 Marin, …). Record Goal, Yellow, Substitution, second Yellow + second-caution send-off, direct send-off; verify full Match Report on watch and mobile pane.

## Production firewall

No changes under `packages/` or `apps/` for this wave.
