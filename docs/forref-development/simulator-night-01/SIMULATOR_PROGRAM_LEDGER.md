# Simulator Night I program ledger

Program: FORREF-SIM-N1.

Execution baseline: `47fd840b36608f882bc354de67e74d60c57b232b`.

Production authority baseline: `39a676b25682e2b6930b6d4f7f02340b55ae01a8`. Production library behavior was not changed.

Implementation commit for the shell: `2dc00f368e1a9590644e751e35797a1075b4fe57`.

Earlier commits on this branch:

| SHA | What was verified before the commit |
| --- | --- |
| `aa7b3af` | Architecture freeze candidate, from the repository as it was. |
| `c50410d` | `research/simulator_geometry`: `dart analyze` clean, `dart test` 20 passed. |
| `4f31ee8` | `research/hf_v2` snapshots, sequenced trace, replay refusal: `dart analyze` clean, `dart test` 61 passed. |
| `2dc00f3` | `research/hf_prototype` Simulator Lab: `flutter analyze` clean, `flutter test` 21 passed. |

## Bank A — isolation

PASS.

`research/hf_prototype` depends on `hf_v2` and `simulator_geometry` only. `simulator_geometry` pubspec has no Flutter, Firebase, Match Core, persistence, or `hf_v2`. The root workspace members remain `match_core`, `forref_match_core`, `forref_match_persistence`, `forref_match_benchmark`, and `apps/referee_phone`.

Tests: `simulator_geometry` isolation test; `hf_v2` isolation test; shell test `the prototype is outside production phone routing` scans the phone `lib/` tree for `hf_prototype`, `hf_v2`, and `simulator_geometry`.

`git status` and `git diff` against the research baseline show no edits under `apps/referee_phone/lib`, `packages/forref_match_core/lib`, `packages/forref_match_persistence/lib`, or `packages/match_core`.

## Bank B — profiles

PASS.

Schema 1, three illustrative starters, pasted JSON import, fail-closed rejection. See `DEVICE_PROFILE_CONTRACT.md`. Profile tests cover a factual candidate loaded without a source change, malformed schema, dimensions, safe area, provenance, contradictory capabilities, certification keys, illustrative millimetres, and no-touch unknown versus unsupported.

## Bank C — geometry

PASS.

Fit round-trip, zoom, letterboxing, unproven raster and physical requests, proven raster and physical scales in unit fixtures, round clipping, phone preferred rectangles, tiny round not-fit, profile isolation, host-origin removal. See `GEOMETRY_AND_CALIBRATION_CONTRACT.md`.

The shell paints the instrument rectangle: adversarial test `painted yellow target matches the instrument rectangle` compares the painted yellow target with the stage transform of `DeviceRect(16, 180, 150, 48)` within 1 px.

## Bank D — snapshots

PASS.

`ResearchTruthSnapshot` copies cautions, sending-offs, substitutions, roster, and officials. Reading it does not append. In-flight subject, scope, and OUT/IN stay frozen. Unknown outcome is neither saved nor a known failure. Two cautions do not append a sending-off. Unavailable history stays unavailable. Sequence numbers reset to 1 on `loadScenario` and increase only after a log event is stored.

## Bank E — device stage

PASS for the widget instrument on Linux tests.

Focus and Inspection exist. The stage is the center. Identity is persistent. Targets come from the active layout and the current page. `LAYOUT NOT FIT FOR THIS PROFILE` hides targets. Commit text comes from `commitLabel`.

Windows desktop was not launched. That limitation is the Windows field in the handoff, not a second interaction engine.

## Bank F — comparison

PASS.

Compare devices builds the three starters from one instrument. One `research-capture` key. Mirrors use `IgnorePointer` and their own `placementFor` rectangles. They do not write `instrument.layout`. Switching profile cancels open pointers and does not append. Adversarial tests `J` and `comparison keeps one history and one active surface`.

## Bank G — scenarios and trace

PASS for load, reset, inspection, and the sequenced trace.

19 core scenarios and 11 variants remain on `ScenarioId`. The inspection rail lists every id. Reset calls `loadScenario` and then reinstalls the active profile layout, because `loadScenario` restores `ResearchLayout.phone`.

Trace kinds added for this program include profile selected, active device changed, pointer down, pointer up, pointer cancelled, focus lost, frozen command, research record appended, layout changed, and input rejected. Sequence is the authority. Wall-clock time is not stored.

Replay is not a bank pass by itself. See the handoff replay line.

## Bridges

| Bridge | Result | Evidence |
| --- | --- | --- |
| 1 Profile to geometry | PASS | A parsed profile feeds `viewportFor` and `resolveActionLayout`. Invalid JSON does not become a viewport. `calibration` on a profile is rejected before geometry. |
| 2 Geometry to input safety | PASS | Painted yellow matches the instrument rect. A round-corner tap does not activate. Profile switch cancels the open pointer. Not-fit installs unreachable rects and hides targets. |
| 3 Input to hf_v2 | PASS | `ResearchController.devicePointerDown/Up` calls the instrument. Widgets do not append cautions, sending-offs, or substitutions. Auto-resolve calls `resolveSimulatedCommit` only when the instrument is `saving`. |
| 4 hf_v2 to inspector | PASS | `TruthInspector` takes a `ResearchTruthSnapshot`. Hold-resolution widget test reads the frozen subject, scope, and pair from the instrument after later edits. |
| 5 hf_v2 to comparison | PASS | One history. Inactive surfaces do not receive the pointer. A profile switch writes no record. |
| 6 Scenarios to trace | PASS | Scenario id, reset, and trace events are on the instrument. The trace strip shows the last events with sequence numbers. Cross-device pointer replay is not part of this pass. |

A passing bank is not what marks the bridge. The rows above name the check that was run.
