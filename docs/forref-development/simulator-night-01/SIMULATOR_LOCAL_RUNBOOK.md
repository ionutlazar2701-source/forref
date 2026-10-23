# Simulator Lab local runbook

Research only. This app is not the referee phone app. A simulated save is not production D1.

## Where it lives

```text
research/hf_prototype          Flutter Simulator Lab
research/hf_v2                 simulated interaction truth
research/simulator_geometry    profiles, transforms, layout
```

These packages are outside the root pub workspace. `./tool/verify_cloud.sh` does not analyze or test them.

## Linux commands used in this session

From the repository root:

```bash
(cd research/simulator_geometry && dart analyze && dart test)
(cd research/hf_v2 && dart analyze && dart test)
(cd research/hf_prototype && flutter analyze && flutter test)
```

Toolchain in this session: Flutter 3.47.2, Dart 3.13.2.

`flutter test` in `research/hf_prototype` is a widget-test run. It is not a Windows desktop launch.

## Windows desktop

Scaffolding was generated on Linux with:

```bash
cd research/hf_prototype
flutter create --platforms=windows --project-name hf_prototype .
```

Flutter 3.47.2 wrote `research/hf_prototype/windows/**` and `research/hf_prototype/.metadata`. The generated counter test and stock README were removed. The app sources in `lib/` were not replaced.

Windows was not built and not launched. This cloud VM has no Windows SDK.

Local command, on a Windows machine with Flutter 3.47.2:

```bash
cd research/hf_prototype
flutter pub get
flutter run -d windows
```

That command is a local gate. A green Linux `flutter test` does not satisfy it.

There is no Linux desktop runner in this project. `flutter run -d linux` is not a supported path until a linux runner is added on purpose.

## What the operator can do

1. The first screen is FORREF SIMULATOR LAB, with RESEARCH / NON-PRODUCTION.
2. Focus mode keeps scenario selection off the device. Inspection opens the scenario list, truth inspector, and trace.
3. Phone profile, Round watch, and Rectangular watch select the three starter profiles.
4. Compare devices shows all three. One surface is ACTIVE. The others are READ ONLY and ignore pointers.
5. Page chips (live, yellow, red, substitution, players, officials, commitment), Home, Away, Match scope, and Shoot-out scope are operator context. They are not final actions.
6. A final action is a pointer on the active device target: Record yellow, Record sending-off, or Record substitution.
7. Hold simulated resolution leaves the commit in `Saving — simulated` so the frozen command can be read. Resolve simulated commit appends only through `ResearchInstrument.resolveSimulatedCommit`.
8. Reset reloads the current scenario and reinstalls the active profile layout.
9. Apply profile JSON parses schema 1. Invalid JSON does not change the active profile.
10. Request raster 1:1 and Request physical 1:1 stay `NOT CALIBRATED` while host evidence is unknown.

## Commit words

| Instrument state | Text |
| --- | --- |
| Saved in the research collection | SIMULATED SAVED — not production D1 |
| Known scripted failure | NOT SAVED — known simulated failure |
| Outcome not known | SAVE NOT VERIFIED — outcome is not known |
| In flight, not yet resolved | Saving — simulated |
| s17 recovery banner | SIMULATED RECOVERY BEHAVIOR |

## Founder diagnostic scenarios

The operator list includes every `ScenarioId`, including:

`s01YellowNoPrior`, `s03YellowPriorUnavailable`, `s05Y2SendOffContinuation`, `s07RapidRepeatAfterY2`, `s08DirectRedWithPriorYellow`, `s09Home14ThenAway14`, `s10SimilarOfficials`, `s12SubstitutionInFirst`, `s14SubstitutionInterruptAfterPair`, `s16SaveNotVerified`, `s17FinishLaterSimulatedRestart`, `s18MatchToShootout`, `s19SentOffHistoricalReview`.

Loading one of these does not require an edit. It is a diagnostic fixture, not a human-performance result.
