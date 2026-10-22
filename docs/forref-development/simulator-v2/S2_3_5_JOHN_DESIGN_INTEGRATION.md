# S2.3.5 — John Design Integration

PROGRAM: FORREF SIMULATOR V2
WAVE: S2.3.5
SCOPE: `research/hf_prototype` presentation only. Research, non-production.

John Design Authority V1 is the accepted visual direction for the Simulator
Lab: the device is the hero, complexity is on demand, and the lab reads as a
professional product laboratory rather than an engineering console. This
wave integrates that direction into the real Flutter lab. It does not add a
second controller, a second truth owner, or a second simulator.

## What John V1 means in this repository

| John V1 intent | Repository realization |
| --- | --- |
| The device is the hero | `FocusWorkspace` mounts the live `WatchReferenceApp` inside the `DeviceShellStage` aperture through `DeviceHeroStage`. Nothing else on the Focus screen competes with it. |
| Complexity on demand | SHA stamps, profile ids, raw journal lines, scenario lists, and permanent debug chips are not on the default screen. They live behind the Inspector, the Device Selector, the Command Lab rail, or the ADVANCED geometry diagnostic. |
| One match context | `MATCH · Research Match` pill in the top bar. The lab holds exactly one `ResearchController` over one `ResearchInstrument` and one `HfPresentationRuntime`. |
| Professional device selection | `DeviceSelector` cards are built from `DeviceProfileV2` facts: manufacturer, model line, raster, shape, and the computed evidence stage. |
| Workspaces | `LabWorkspace { focus, commandLab, compare, matchBuilder }` as tabs on the workspace bar, or a dropdown below 800 px. |
| Inspector | `LabInspector` with `InspectorSection { truth, eventJournal, deviceEvidence }`. Closed by default. Inline beside the stage at 1440 px and above; an overlay below that. |

## Repository facts override John's illustrative values

John's HTML carried illustrative numbers and badges. Where they contradict the
`DeviceProfileV2` catalog, the catalog wins and the HTML value is not shown.

| Illustrated in John V1 | Repository fact | Lab shows |
| --- | --- | --- |
| Apple Watch Series 9 45 mm raster | `rasterWidth` and `rasterHeight` are `FactStatus.unknown` | `RASTER UNKNOWN` |
| Garmin Approach S60 case and shape | case width and screen shape unknown | `RASTER UNKNOWN · shape unknown`, `?` glyph on the card |
| Safe area and aperture measurements | `SafeAreaFact` and `ShellApertureFact` unknown for every seed profile | `APERTURE NOT MEASURED`, `UNCALIBRATED VIEW` |
| `PLATFORM PROVEN`, `FORREF CERTIFIED`, `SIMULATION READY` badges | `profileV2EvidenceStage` computes only `profiled` for the seed profiles | `PROFILED` only. Device Evidence lists `PLATFORM PROVEN` and `FORREF CERTIFIED` as `NOT ESTABLISHED` |
| A single `DEGRADED` banner on the device | the viewport basis is a per-profile fact (`viewportContextFor`) | `DEGRADED · raster fallback…` or `DEGRADED · design coordinate space…` in the stage footer line |

Amazfit GTS 4 (390 × 450, rounded rectangle derived) and Huawei Watch GT 4
46 mm (466 × 466, round derived) are the two profiles with known rasters.
Huawei Watch GT 4 46 mm is the default shell. Amazfit GTS 4 is the default
Compare partner. No geometry was invented to make the other two look complete.

## Truth paths kept separate

The lab presents two paths that must never be confused.

| Path | Entry | Store | Label |
| --- | --- | --- | --- |
| Research watch path | `WatchReferenceApp` → `WatchIntent` → `HfPresentationRuntime` → `hf_v2` | in-memory research instrument | `SIMULATED SAVED — not production D1` |
| Integration Sandbox | `SandboxSession.commitYellow()` | isolated file-backed SQLite under a temporary directory | `SANDBOX D1 COMMITTED` |

Three origins are displayed and traced: `ACTUAL WATCH UI INTERACTION`,
`OPERATOR FIXTURE ACTION`, `INTEGRATION SANDBOX ACTION`. A tap inside the
watch aperture is never labelled as a SQLite commit. The Event Journal states
this in its sandbox-origin warning, shows the research commit phrase on a
separate `journal-research-commit` line, and derives every causal stage from
observed `JournalEntry` records only. A stage without an entry reads
`NOT OBSERVED`. The research watch path does not prove SQLite D1, and this
wave built no bridge between them.

## Banks

| Bank | Content | Result |
| --- | --- | --- |
| A Shell | `LabWorkspace`, `InspectorSection`, `LabLayoutRegime`, `LabTopBar`, `WorkspaceBar`, `LabFooter`, `LabScaffold`. Inspector closed by default. Identity text exactly once per regime (top bar when wide, footer otherwise). | PASS |
| B Device Selector | `DeviceSelector` over `factualSeedProfiles`. Facts only. `PROFILED` only. `SELECTED` marks the current shell. Scrim closes without selecting. Stage evidence caption removed from the default screen (`showEvidenceCaption` defaults to false). | PASS |
| C Focus | `DeviceHeroStage` with zoom controls, `OutcomeRibbon` for the current research result, factual stage footer line, `View device evidence` shortcut. | PASS |
| D Command Lab | `CommandRail` 240–280 px grouped SCENARIO / INTERACTION / FAILURE-COMMIT / RUNTIME / ADVANCED. Every rail action dispatches through the runtime with `IntentOrigin.operatorFixture`. The Night I geometry stage is the ADVANCED diagnostic, reached by `openGeometryStage()` and labelled as illustrative. Below 1100 px the rail is a drawer. | PASS |
| E Compare | Two factual shells on one `HfPresentationRuntime`. Exactly one `ACTIVE INPUT`; the other is `READ ONLY` through `interactive: false` (`IgnorePointer`). Switching the owner bumps `inputEpoch` and cancels held gestures. No pointer replay between shells. Narrow windows show one device at a time with a switch button. | PASS |
| F Inspector | F1 Truth: ESTABLISHED / IN-FLIGHT / VISIBLE ON DEVICE / SAFETY from the instrument snapshot and the presentation state. F2 Event Journal: eight causal stages from observed `JournalEntry` only, `DESKTOP SANDBOX MEASUREMENT`, research line separate. F3 Device Evidence: IDENTITY / DISPLAY / CASE / INPUT / FIDELITY / PROVENANCE with `KNOWN` / `DERIVED` / `UNKNOWN` badges and expandable derivation, uncertainty, and sources. | PASS |
| G Match Builder | `MATCH BUILDER — S2.4` placeholder with MATCH / TEAMS & SQUADS / OFFICIALS & CREW / FORMAT / REVIEW. Non-authoritative. Writes nothing. | PASS as placeholder |
| H Responsive | `wide ≥ 1440`, `desktop ≥ 1100`, `compact ≥ 800`, `narrow < 800`. A regime change raises `layoutEpoch` and `inputEpoch` and calls `instrument.focusLost()`, so a press held across a resize records nothing. Verified at 1600 / 1440 / 1280 / 1100 / 900 / 760. | PASS |

## Bridges

| Bridge | Result |
| --- | --- |
| Watch tap in the aperture → `WatchIntent` → runtime → `hf_v2` → projected `WatchPresentationState` | PASS, origin `ACTUAL WATCH UI INTERACTION` |
| Rail button → runtime → same instrument | PASS, origin `OPERATOR FIXTURE ACTION`, traced separately |
| Instrument snapshot → Truth inspector | PASS, read-only projection |
| `JournalEntry` list → causal stage view | PASS, `NOT OBSERVED` when absent |
| `DeviceProfileV2` → selector card, stage footer, evidence view | PASS, unknown stays unknown |
| Compare owner switch → `inputEpoch` → `WatchReferenceApp` hold guard | PASS, in-flight cleared |
| Regime change → `layoutEpoch`, `inputEpoch`, `focusLost()` | PASS |
| Research watch input → SQLite D1 | NOT BUILT. Not authorized. Not claimed. |

## Deviations from John's HTML, recorded

- The `DEGRADED` word is in the stage footer line, next to the viewport basis
  it describes, not on a device banner.
- Geometry diagnostics (Night I buttons, layout fit, pointer rejection) are
  reachable only from the Command Lab ADVANCED group, labelled illustrative.
- Icon glyphs in Linux widget-test captures render as boxes because the
  Material icon font is not loaded in the test binding. That is a capture
  artifact, not the application.
- The watch canvas is laid out at the aperture's on-screen size. In the
  compact regime at low heights (for example 900 × 700 with the drawer open)
  the GTS 4 aperture can fall below `minimumActionExtent` and the watch fails
  closed with `LAYOUT NOT FIT FOR THIS PROFILE`. That is the existing
  `watch_reference_ui` contract, kept deliberately; scaling the canvas to
  hide it would misrepresent control sizes.
- `WatchReferenceApp` content is clipped by the round Huawei aperture at the
  corners. The reference UI has no round-safe layout yet; the clip is honest.

## Evidence

Frames at 1440 × 900 unless noted, written by `test/john_visual_test.dart`
to `$TMP/forref-sim-v2/` and to `/opt/cursor/artifacts/` when present. Each
frame carries a footer stamp with SHA, workspace, profileId, runtime,
scenario, and fidelity. `john-evidence-manifest.json` records the same fields
plus the watch commit label and the caution and send-off counts.

| Frame | Content |
| --- | --- |
| `01-john-focus.png` | default launch, Huawei Watch GT 4 46 mm, inspector closed |
| `02-john-device-selector.png` | four seed profiles, `PROFILED` only, `RASTER UNKNOWN` for Apple and Garmin |
| `03-john-command-lab.png` | operator fixture yellow frozen, rail outside the watch |
| `04-john-compare.png` | Huawei active input, Amazfit read-only mirror, same semantic state |
| `05-john-truth-inspector.png` | Truth after `SIMULATED SAVED — not production D1` |
| `06-john-event-journal-not-observed.png` | every causal stage `NOT OBSERVED` after a research yellow |
| `07-john-event-journal-sandbox.png` | stages observed from `dart run bin/capture_report.dart`, `SANDBOX D1 COMMITTED`, `DESKTOP SANDBOX MEASUREMENT` |
| `08-john-device-evidence.png` | Apple Watch Series 9 45 mm, 19 facts `UNKNOWN` |
| `09-john-match-builder.png` | S2.4 placeholder, non-authoritative |
| `10-john-watch-yellow.png` | Amazfit GTS 4, Yellow tapped on the watch, `ACTUAL WATCH UI INTERACTION` |
| `11-john-compact-900.png` | 900 × 700, commands drawer, fail-closed layout on the small aperture |
| `12-john-narrow-760.png` | 760 × 900, Compare with one device at a time |

These are Linux desktop captures. They are not Windows evidence, not human
validation, and not device evidence.
