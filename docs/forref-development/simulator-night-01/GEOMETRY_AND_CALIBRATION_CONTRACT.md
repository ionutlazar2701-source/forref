# Geometry and calibration contract

Package: `research/simulator_geometry`. Layout policy version: 1 (`layoutPolicyVersion`). Minimum action extent: 48 logical pixels (`minimumActionExtent`).

The geometry package does not import Flutter, `hf_v2`, Match Core, persistence, or Firebase.

## Coordinate spaces

| Space | Type | Meaning |
| --- | --- | --- |
| Device logical | `DevicePoint`, `DeviceRect` | Profile viewport. Hit regions live here. |
| Device raster | profile raster fields | Used only when `known` and host device-pixel ratio is known. |
| Simulator stage | `StagePoint` | Pixels inside the device stage after fit, origin, and scale. |
| Host pointer | `HostPoint` | Pointer position before the stage origin is removed (`hostToStage`). |
| Physical millimetres | `PhysicalTargetSize` | Only for a factual profile with known physical size. |

`ViewTransform.toStage` and `toDevice` are inverses for a usable view. Tests cover letterboxing, centering, and zoom.

## Calibration

`assessView` takes the profile, stage size, requested mode, host evidence, and zoom.

Zoom is accepted from 0.25 through 3. An invalid zoom is not honored; the fit scale is used and the label is `NOT CALIBRATED`.

| Requested mode | Honored when | Label when honored | Otherwise |
| --- | --- | --- | --- |
| `FIT` | Stage size is positive. Zoom may change the fit scale. | `Calibration: FIT` | `NOT CALIBRATED` if the stage is unusable. |
| `RASTER_1_TO_1` | Raster size is known, host device-pixel ratio is known and positive, zoom is 1. | `Calibration: RASTER_1_TO_1` | `NOT CALIBRATED`. The view still uses the fit scale so something is drawn. |
| `PHYSICAL_1_TO_1` | Physical millimetres are known, host millimetres per logical pixel are known, logical pixels map uniformly to millimetres within 0.01, zoom is 1. | `Calibration: PHYSICAL_1_TO_1` | `NOT CALIBRATED`. |

`Physical fidelity` is `PHYSICAL_1_TO_1` only when that mode is actually honored. FIT is not physical fidelity. The physical-fidelity line stays `NOT CALIBRATED` for FIT and for unproven raster.

`HostDisplayEvidence.unknown` is the lab default. The operator cannot paste host proof into a profile.

`physicalTargetSize` returns null unless the profile is factual and physical size is known. The lab then shows `PHYSICAL TARGET SIZE UNKNOWN`. Illustrative starters always take that path. A 48 by 48 logical target on a factual profile is converted with the profile's own millimetres per logical pixel, not the host screen's millimetres.

## Clipping and safe area

`ViewportGeometry.containsVisible` follows the shape: rectangle, circle, or rounded rectangle. `containsSafe` applies insets or the circular inset. A point in the bounding box of a circle but outside the disc is not visible. A point on the disc but outside the safe inset is visible and not safe.

The device stage clips painting to the same shape. Pointer down is forwarded only as an acceptance when the inverse-transformed point is both visible and inside the safe area. Outside points call `noteInputRejected('outside-visible-or-safe')` and do not arm a target.

## Layout policy

`resolveActionLayout` places action slots in device-logical coordinates.

Preferred rectangles are kept only when every action, and the roster when supplied, sits fully inside the safe region, meets its minimum, and does not overlap another slot. The phone starter uses the Session III rectangles because the 8 px inset still contains them: yellow `16,180,150x48`, sending-off `220,180,160x48`, substitution `16,250,200x48`.

If preferred placement fails, a centered column is tried at width 112, then at the 48 minimum, height 48, gap 8. Every corner of each column rect must lie in the safe region. Controls are not shrunk below 48. If neither column fits, the result is `fits: false` and the label is `LAYOUT NOT FIT FOR THIS PROFILE`.

The lab installs `unreachableResearchLayout` (negative coordinates) when the layout does not fit, draws no action targets, and shows that label. A bounded column that fits parks the roster at `(-1000,-1000,48x48)` so it is not a hit target on the watch face. That column is a research placement, not a native watch interaction pattern.

`evidenceStageFor` returns `simulationReady` only when geometry accepts the profile and the layout fits. Otherwise `profiled`.

Changing profile does not share transform state. Each `assessView` call is pure.
