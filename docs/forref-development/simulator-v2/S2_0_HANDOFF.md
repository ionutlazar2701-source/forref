# S2.0 handoff — device catalog v2 and presentation runtime

PROGRAM: FORREF SIMULATOR V2
WAVE: S2.0
STATUS: PASS

INPUT SHA: `0922f1ff97a3f9bec1c052f18fc9db485515316e`
IMPLEMENTATION TIP: `50709edf81d92fadb277c2ee96376afadfefc7f9`
The commit that adds this handoff is the wave documentation tip. Do not predict a later SHA.

PRODUCTION AUTHORITY BASELINE: `39a676b25682e2b6930b6d4f7f02340b55ae01a8`
PRODUCTION AUTHORITY MODIFIED: NO

## Preflight

- Branch `cursor/forref-simulator-v2` was created from `cursor/forref-simulator-night-01`.
- HEAD at start was `0922f1ff97a3f9bec1c052f18fc9db485515316e`.
- Worktree was clean. Nothing was reset, stashed, or discarded.
- PR #24 was not merged.

Files inspected before editing:

- `AGENTS.md`
- `docs/architecture-authority.md`
- `docs/forref-development/simulator-night-01/` (all seven Night I documents; not rewritten)
- `research/simulator_geometry/lib/**`
- `research/hf_v2/lib/**`
- `research/hf_prototype/pubspec.yaml`
- uploaded research report `simlabv2` (architecture input, not repository truth)

## Architecture interpretation

Night I remains the research sporting authority (`research/hf_v2`) and the schema v1 geometry tester. S2.0 adds an evidenced schema v2 catalog and a pure-Dart presentation contract. The adapter lives in `research/simulator_hf_bridge` so `hf_v2` does not depend on presentation and presentation does not depend on the instrument. Shells, the watch reference app, the sandbox, and the match builder are later waves.

## Contradictions with the research report

These are fact limits, not a stop of S2.0:

- Night I handoff says Windows was not launched. The founder later observed a Windows launch on Flutter 3.47.2. That observation is recorded only in Simulator V2 docs. Night I documents were not edited.
- Schema v1 requires a safe area. Schema v2 represents unknown safe area without storing zero. v1 profiles are unchanged.
- The report's example JSON is ahead of pages re-fetched in this session. Unconfirmed numbers were not stored as known. See `DEVICE_CATALOG_EVIDENCE.md`.
- `hf_v2` has no match clock and no score. Presentation labels both unavailable. It does not invent 0-0 or 00:00.
- Seed profiles are PROFILED. Shell aperture is unknown, so they are not SIMULATION READY.

## Banks

| Bank | Result |
| --- | --- |
| S2.0-A Device profile v2 | PASS |
| S2.0-B Factual catalog | PASS |
| S2.0-C Presentation contract | PASS |
| S2.0-D hf_v2 presentation adapter | PASS |

## Bridges

| Bridge | Result |
| --- | --- |
| Profile v2 ↔ viewport context | PASS |
| Catalog ↔ profileId selector | PASS |
| Research snapshot ↔ presentation state | PASS |
| WatchIntent ↔ ResearchInstrument | PASS |
| Active profile ↔ viewport context | PASS |

The Flutter lab selector still lists Night I illustrative profiles. Named-device selection in the lab UI is S2.1.

## What changed

- `research/simulator_geometry`: `EvidenceFact`, schema v2 parser, viewport context, four seed profiles.
- `research/simulator_presentation`: presentation state, intents, in-memory runtime. No Flutter, no persistence.
- `research/simulator_hf_bridge`: projection and dispatch.
- `research/hf_v2`: snapshot now exposes the existing `yellowOffered` and `directSendOffOffered` flags. No sporting rule changed.

Watch intents do not append caution, send-off, or substitution lists. `accessibilityInvoke` and `resolveSimulatedCommit` remain the instrument methods.

## Tests

| Package | Result |
| --- | --- |
| `research/simulator_geometry` `dart analyze` | No issues found |
| `research/simulator_geometry` `dart test` | 32 passed |
| `research/simulator_presentation` `dart analyze` | No issues found |
| `research/simulator_presentation` `dart test` | 3 passed |
| `research/hf_v2` `dart analyze` | No issues found |
| `research/hf_v2` `dart test` | 61 passed |
| `research/simulator_hf_bridge` `dart analyze` | No issues found |
| `research/simulator_hf_bridge` `dart test` | 9 passed |

Night I geometry and hf_v2 tests were not deleted or weakened.

## Adversarial checks in this wave

- Unknown fact with value 0 rejected.
- Known measurement 0 rejected.
- Certification and evidence-stage JSON rejected.
- JSON cannot award SIMULATION READY.
- Amazfit native logical viewport stays unknown. Design benchmark 390×450 is labeled not native.
- Apple raster stays unknown. Crown press stays unknown.
- Garmin case, raster, and buttons stay unknown.
- In-flight Home 14, MATCH scope, and OUT 9 / IN 7 stay frozen.
- Second-caution send-off before a successor writes nothing.
- Unavailable prior caution is not projected as known none.
- Profile bind does not append a record.
- No `isGarmin` / `isHuawei` / `isApple` / `isAmazfit` branch in geometry.

INDEPENDENT SABOTEUR NOT AVAILABLE

## Open risks

- Lab UI does not yet render these profiles.
- Apple logical viewport and Garmin physical facts are unknown, so later shells for those two must not pretend the missing numbers are exact.
- Amazfit touch and crown are unknown. One physical key is known and is not labeled a crown.
- Clock and score stay unavailable until a runtime actually has them.

## Next safe wave

S2.1 real device shells and display aperture. Prerequisite S2.0 PASS is met.

WINDOWS APPLICATION LAUNCH: OBSERVED PASS is the founder's Night I launch on Flutter 3.47.2. This cloud session did not run Windows. That observation is not human validation, native fidelity, production D1, or certification.
