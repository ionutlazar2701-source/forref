# Simulator architecture freeze candidate

Status of this file: CANDIDATE, written from the repository before Simulator Night I code changes.

Execution baseline: `47fd840b36608f882bc354de67e74d60c57b232b`

Branch tip that contains it: `origin/cursor/forref-night-hf-prototype-30fd`

Production authority baseline: `39a676b25682e2b6930b6d4f7f02340b55ae01a8`

Working tree at branch creation: clean.

This candidate organizes research packages and presentation. It does not reopen Match Core authority, sporting rules, or production persistence.

## 1. Repository baseline

`main` at the cloud checkout was `919c9062d607f0af255ad368b8c6cb2658d6c85a`. That commit does not contain Night Session III. The accepted research baseline is an ancestor-descendant of that main commit: merge-base is `919c906`, and `47fd840` is the Session III handoff.

Session III already isolated:

- `research/hf_v2` — deterministic research instrument. Mutable `ResearchInstrument`, immutable record objects, `ResearchLayout.phone` rectangles, pointer down/up/cancel, focus loss, scripted commit resolution, activation snapshot `_ActivatedCommand`.
- `research/hf_prototype` — Flutter shell. `ResearchController` forwards pointers and resolves a simulated commit on pointer up. Capture column and operator panel are mutually exclusive.

`packages/forref_match_core` and `packages/forref_match_persistence` are production authority. They are not imported by `hf_v2` or `hf_prototype`. The root pub workspace does not list the research packages.

## 2. Current research package responsibilities

| Package | Responsibility now |
| --- | --- |
| `research/hf_v2` | One simulated interaction truth: scenario fixture, unfinished selection, frozen command, simulated commit, research log. |
| `research/hf_prototype` | Operator shell over that instrument. Not a route in the phone app. |
| `research/a_physical` | Separate fail-closed physical-gate checker. Not the simulator and not a certification. |
| `research/live_core_a` | Separate live-core study harness. Out of this program. |

`ResearchLayout.phone` is phone-oriented: yellow `16,180,150x48`, sending-off `220,180,160x48`, substitution `16,250,200x48`. Hit testing uses those rectangles plus offer flags. A yellow rectangle is not a sending-off. Two saved cautions do not append a sending-off.

`_ActivatedCommand` freezes subject, kind, scope, and OUT/IN at activation. Later edits stay on the unfinished layer. `SIMULATED SAVED` is returned only when `_applySuccess` appends a record.

## 3. Proposed package dependency DAG

```text
apps/referee_phone
  does not import research packages

packages/forref_match_core
packages/forref_match_persistence
  no dependency on research simulator packages

research/hf_v2
  pure Dart
  no Flutter, Firebase, match core, or persistence

research/simulator_geometry
  pure Dart
  no Flutter, Firebase, hf_v2, match core, or persistence

research/hf_prototype
  Flutter
  depends on hf_v2 and simulator_geometry
  no match core, no persistence, no Firebase
```

One Flutter research application remains: `research/hf_prototype`. It is evolved into FORREF Simulator Lab. No second research state engine. No second Match Core.

## 4. One source of simulated interaction truth

`ResearchInstrument` remains the only writer of simulated cautions, sending-offs, and substitutions.

The shell may call existing instrument methods. It may not append those lists from a widget. A profile change, a rebuild, a comparison layout, and a zoom change are not commits.

The geometry package places rectangles. It does not record sporting events.

## 5. Production Match Memory write paths

Allowed research imports stop at `hf_v2` and `simulator_geometry`.

No `DurableCommitPort`, no `SqliteDurableMatchStore`, no `package:forref_match_core`, no `package:match_core`, no phone router edits.

Simulated success text stays `SIMULATED SAVED — not production D1`.

## 6. Device profile schema and evidence contract

Schema version 1, pure data.

A profile may be classified `illustrative` or `factual`. Factual claims need provenance. Illustrative profiles do not carry physical millimetres.

Capability values are `supported`, `unsupported`, or `unknown`. Unknown is not unsupported.

Evidence stages the simulator may assign after its own checks: `PROFILED`, and `SIMULATION READY` when geometry and the layout policy pass.

`PLATFORM PROVEN` and `FORREF CERTIFIED` are not states a profile can set. A JSON field that asserts them rejects the profile.

Starter fixtures, all illustrative, physical size unknown, raster unknown:

- illustrative phone portrait
- illustrative round watch
- illustrative rectangular watch

No manufacturer branch in the engine. Manufacturer and model are optional metadata.

## 7. Geometry and coordinate system

Spaces:

1. Device logical coordinates.
2. Device raster coordinates, only when the profile says they are known.
3. Simulator stage coordinates.
4. Host pointer coordinates.
5. Physical millimetres, only with physical evidence on the profile.

`FIT` scales the logical viewport into the stage and letterboxes it. It is not a physical-size claim.

`RASTER_1_TO_1` is honored only when raster size and host device-pixel ratio are both known to the runtime. A profile cannot supply that host proof.

`PHYSICAL_1_TO_1` is honored only when physical millimetres and host millimetres per logical pixel are both known. Otherwise the status is `NOT CALIBRATED`.

Hit-target millimetres are shown only from evidenced physical dimensions. Otherwise `PHYSICAL TARGET SIZE UNKNOWN`.

The render transform and the pointer inverse are the same function pair. Round profiles clip to the circle. Points in the letterbox, outside the circle, or outside the safe region are not hits.

Phone research rectangles are used only when they sit inside that profile's safe geometry. Other viewports get a bounded placement at or above a 48 logical-pixel minimum. If that placement does not fit, the stage says `LAYOUT NOT FIT FOR THIS PROFILE` and installs no on-screen action target.

## 8. Single-active-device interaction

One `ResearchInstrument` layout is installed: the active profile's placement.

Pointer down is cancelled when the active profile changes. Pointer up after that cancel does not activate. The change does not resolve a commit and does not append a record.

Inactive comparison surfaces are read-only. They do not own a second history.

## 9. Comparison views

Phone, round, and rectangular starters can be shown together. They read the same scenario, the same records, and the same unfinished selection. Only the active surface accepts pointers.

## 10. Trace and replay

The research log gains a monotonic sequence. Wall-clock time is not authority.

New log kinds are additive. Reset still reloads the fixture and clears the log.

Semantic replay calls instrument methods. Pointer replay runs only when the trace names the same profile id and layout-policy version. A mismatch refuses the trace and does not insert a saved record.

Full cross-device pointer replay is not claimed by this candidate.

## 11. Desktop runtime

Primary operator target remains Windows desktop. This cloud environment is Linux. Flutter test and dart test are the cloud evidence. A Windows run is a local gate until it actually happens on Windows.

Windows runner files, if added, stay inside `research/hf_prototype`.

## 12. Human-factors and hardware limits

The lab does not certify a watch, a wet screen, battery life, OS process death, or production D1. Founder scenarios stay available from the scenario list. No human results are invented.

Session III final-action safety and the activation freeze stay in force.

## 13. Out of scope

- Phone authority cutover
- Production Match Memory, persistence schema, and D1
- Production recovery and Finish Later
- Native Wear OS, watchOS, Garmin, Zepp, Huawei
- Cloud sync and authentication
- Sporting-rule changes
- A second `hf_v2`
- Embedding the simulator in the phone binary
- Awarding platform proof or FORREF certification

## 14. File ownership

| Bank | Paths |
| --- | --- |
| A, E, F | `research/hf_prototype/**` |
| B, C | `research/simulator_geometry/**` |
| D, G | `research/hf_v2/**` |
| Documents | `docs/forref-development/simulator-night-01/**` |

Production `apps/referee_phone/lib/**`, `packages/forref_match_core/lib/**`, `packages/forref_match_persistence/lib/**`, and `packages/match_core/**` stay untouched.

## 15. Falsifiable gates

| Gate | Pass condition |
| --- | --- |
| Isolation | Research pubspecs and libraries do not name production authority. Phone lib does not name the simulator. |
| Profile | A valid unseen JSON profile loads. Malformed, unproven certification, missing provenance, and impossible geometry are rejected. |
| Transform | Forward and inverse round-trip. Letterbox and round corners do not hit. Unproven calibration reads `NOT CALIBRATED`. |
| Layout | Phone preferred rectangles survive on the phone fixture. A tiny viewport reports layout not fit and has no action target. |
| Snapshot | Inspector data comes from an immutable snapshot. In-flight subject, scope, and OUT/IN survive later edits. Saved requires an append. |
| Safety | Existing final-action tests still pass. Profile switch mid-pointer does not activate. |
| Truth labels | Unknown outcome is neither simulated saved nor known not saved. |
| Production | `git diff` against the baseline shows no production library edits. |
