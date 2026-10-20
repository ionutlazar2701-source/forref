# S2.2 handoff — watch reference app inside the shell

PROGRAM: FORREF SIMULATOR V2
WAVE: S2.2
STATUS: PASS

INPUT SHA: `51d96806876a1b657b2f90ae8f74bf2fc02b1489`
IMPLEMENTATION TIP: `39139906b40b2b4d1bdbfa8f190b1bbe48f1b77c`

Watch package commit: `2204fe3`

PRODUCTION AUTHORITY MODIFIED: NO

`git diff 0922f1ff97a3f9bec1c052f18fc9db485515316e -- packages apps` is empty.

## Banks

| Bank | Result |
| --- | --- |
| S2.2-A Watch reference UI | PASS |
| S2.2-B Watch screen registry | PASS |
| S2.2-C App in viewport | PASS |
| S2.2-D Command Lab | PASS |
| S2.2-E Device adaptation | PASS |

## Bridges

| Bridge | Result |
| --- | --- |
| WatchPresentationState → WatchReferenceApp | PASS |
| WatchIntent → ResearchInstrument | PASS |
| DeviceShellStage → aperture → app | PASS |
| Operator fixture origin versus watch UI origin | PASS |
| Active profile → degraded viewport label | PASS |

Command Lab is the operator chip `Operator fixture: yellow Home 14`. It dispatches through `HfPresentationRuntime` with origin `OPERATOR FIXTURE ACTION`. It does not append records itself.

The geometry stage still has the Night I sporting buttons. Those buttons are not mounted while a factual shell is open.

## Attacks

| Attack | Result |
| --- | --- |
| Second-caution send-off before a successor | No send-off, no in-flight command |
| Home 14 frozen, then Away | Frozen subject stays `p-home-14` |
| OUT 9 / IN 7 frozen, then a later IN | Frozen pair stays. No substitution record |
| Focus loss during Record yellow | No caution and no in-flight command |
| Profile change during Capture press | Route stays live. No caution |
| Device switch after simulated yellow | Caution count stays 1 |

INDEPENDENT SABOTEUR NOT AVAILABLE

## Screenshots

Linux widget renders. Not a Windows launch. Stamped SHA `39139906b40b2b4d1bdbfa8f190b1bbe48f1b77c`, runtime Research, scenario `s01YellowNoPrior`, fidelity schematic.

- `06-watch-live.png` — amazfit-gts4, Capture inside the shell
- `07-yellow-flow.png` — amazfit-gts4
- `08-y2-sendoff-separated.png` — amazfit-gts4
- `09-substitution.png` — amazfit-gts4
- `10-device-switch-same-state.png` — apple-watch-series9-45 after one simulated yellow
- `11-command-lab.png` — huawei-watch-gt4-46, operator fixture origin

## Tests

| Package | Result |
| --- | --- |
| `research/simulator_geometry` | analyze clean, 37 passed |
| `research/simulator_presentation` | analyze clean, 3 passed |
| `research/hf_v2` | analyze clean, 61 passed |
| `research/simulator_hf_bridge` | analyze clean, 9 passed |
| `research/watch_reference_ui` | flutter analyze clean, 3 passed |
| `research/hf_prototype` | flutter analyze clean, 32 passed |

`bash ./tool/verify_cloud.sh` was not re-run for this wave.

WINDOWS: not run in this session. Founder Night I launch remains OBSERVED PASS and is not a new Windows proof.

HUMAN VALIDATION: NOT RUN

WATCH HARDWARE: NOT TESTED

## Open risks

- Seed shells stay schematic. Safe area stays unknown. Garmin remains an unknown plate.
- A frozen command is not discarded by focus loss. Focus loss cancels a press that has not committed.
- Clipped text at the aperture rim is the clip. It is not a second app surface.

## Next safe wave

S2.3 may import production Match Core and persistence into `research/simulator_sandbox` only. Production library semantics stay read-only. If a production semantic change seems necessary, stop.
