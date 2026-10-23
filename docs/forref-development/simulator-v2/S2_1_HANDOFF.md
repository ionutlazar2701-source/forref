# S2.1 handoff — device shells and display aperture

PROGRAM: FORREF SIMULATOR V2
WAVE: S2.1
STATUS: PASS

INPUT SHA: `805b3db51f05563e5fb0b151bce38406575a2328`
IMPLEMENTATION TIP: `69775730b6362d89033e25552c586e26ba963837`

PRODUCTION AUTHORITY MODIFIED: NO

## Banks

| Bank | Result |
| --- | --- |
| S2.1-A Device shell manifest | PASS |
| S2.1-B Device shell renderer | PASS |
| S2.1-C Display aperture | PASS |
| S2.1-D Hardware control representation | PASS |

## Bridges

| Bridge | Result |
| --- | --- |
| DeviceProfileV2 ↔ DeviceShellManifest | PASS |
| Shell ↔ display aperture | PASS |
| Host pointer ↔ display coordinates | PASS |
| Shell hardware control ↔ simulated hardware input | PASS as visual only |

Crown and side-key marks are drawn. None of those anchors set `simulatedChannel`. A tap on them is not a sporting action.

## Fidelity

| Profile | Silhouette | Fidelity |
| --- | --- | --- |
| amazfit-gts4 | Rounded body from the 390×450 design aspect, one physical-key mark | schematic |
| huawei-watch-gt4-46 | Round case, circle from the 1.43 inch diagonal, crown and side key | schematic |
| apple-watch-series9-45 | Rounded 38×45 mm case, schematic inset, crown and side key | schematic |
| garmin-approach-s60 | Plate. Case geometry unknown. No invented watch shape | schematic |

All four say the aperture is not measured and the safe area is unknown.

## Screenshots

Linux widget renders, not a Windows launch:

- `01-amazfit-gts4-shell.png`
- `02-huawei-gt4-shell.png`
- `03-apple-watch-series9-shell.png`
- `04-garmin-s60-shell.png`
- `05-display-aperture-inspection.png`

Each image is stamped with SHA `69775730b6362d89033e25552c586e26ba963837`, the profile id, runtime Research, scenario none, and fidelity schematic.

The child in these images is the diagnostic viewport. The FORREF watch reference app is S2.2.

## Tests

| Package | Result |
| --- | --- |
| `research/simulator_geometry` `dart test` | 37 passed |
| `research/hf_prototype` `flutter analyze` | No issues found |
| `research/hf_prototype` `flutter test` | 25 passed, including shell stage and shell visual |

Adversarial checks: bezel and strap are not the aperture; a round-case corner is not the bezel or the aperture; profile switch cancels an open pointer; JSON aperture facts stay unknown.

INDEPENDENT SABOTEUR NOT AVAILABLE

## Next safe wave

S2.2 mounts the FORREF Watch Reference App inside this aperture and removes sporting buttons from the hardware stage.
