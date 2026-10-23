# Device profile contract

Schema version: 1 (`deviceProfileSchemaVersion`).

Package: `research/simulator_geometry`. Parser: `parseProfile`. Encoder: `encodeProfile`.

A profile describes a candidate device. It does not certify a device, and it does not write Match Memory.

## Evidence stages the simulator may assign

The simulator computes the stage. Profile JSON cannot set it.

| Stage | Meaning in this program |
| --- | --- |
| PROFILED | A schema-1 profile parsed. |
| SIMULATION READY | The profile's geometry is accepted and the research action layout fits. |

`PLATFORM PROVEN` and `FORREF CERTIFIED` are not stages this package can award. Keys and string values that assert them are rejected (`certification-claim`).

Rejected self-assertions include `certification`, `forrefCertified`, `platformProven`, `evidenceTier`, `certified`, `hardwareProven`, `nativeCrown`, and `simulatedTouchIsHardware`. A profile also cannot carry a `calibration` object (`invalid-calibration`). Host calibration is runtime evidence, not profile data.

## Classification

`illustrative` or `factual`.

Illustrative profiles cannot carry known physical millimetres. Factual profiles must name provenance: source type, source reference, and, when a date or method is present, text rather than a silent omission.

Unknown is not unsupported. Each input channel is `supported`, `unsupported`, or `unknown`.

Channels: touchscreen, crown, physical buttons, rotating bezel, gesture input, accessibility invocation.

## Shapes

`rectangle`, `round`, `roundedRectangle`.

A round profile must be square and use `circularMask`. A rectangle uses `edgeClipping: none`. A rounded rectangle needs `roundedMask` and a non-negative corner radius.

## Required fields

`schemaVersion`, `profileId`, `displayName`, `deviceClass` (`phone` or `smartwatch`), `screenShape`, `classification`, `logicalViewport`, `rasterDimensions`, `physicalDisplayDimensionsMm`, `safeArea`, `edgeClipping`, `cornerRadius`, `inputCapabilities`, `typography.minimumLogicalSp`, `provenance`.

Manufacturer and model are optional metadata. They do not select code paths.

Raster and physical sizes are `{known: false}` or `{known: true, width, height}` with positive finite numbers. A known-false size must not also carry numbers.

Safe area is either insets or a circular inset. Insets that cover the viewport, negative insets, and inverted edges are `impossible-safe-area`. Zero or negative logical dimensions are `non-positive-dimension`.

Unknown top-level keys are `unknown-field`. Schema versions other than 1 are `unsupported-schema`. Malformed JSON fails closed and does not replace the active profile.

## Starter fixtures

These are generic research fixtures. Their dimensions are illustrative, not measurements of a commercial product. Raster and physical size are unknown. Touch `supported` on a starter is an illustrative assumption, not a hardware proof.

| profileId | Class | Shape | Logical size | Safe area | Crown |
| --- | --- | --- | --- | --- | --- |
| `illustrative-phone-portrait` | phone | rectangle | 390 x 844 | insets 8 | unsupported |
| `illustrative-round-watch` | smartwatch | round | 240 x 240 | circular inset 12 | unknown |
| `illustrative-rectangular-watch` | smartwatch | rectangle | 192 x 228 | insets 8 | unknown |

Phone physical buttons and gesture input are unknown. Watch physical buttons and gesture input are unknown. The rectangular watch rotating bezel is unsupported. The round watch rotating bezel is unknown.

## Import

The Simulator Lab operator rail accepts pasted JSON (`profile-import`). A rejected profile leaves the active profile unchanged and shows the violation text. An accepted profile is added to the research catalog and becomes active. Switching cancels an open pointer sequence and does not append a research record.

Encode-then-parse of a starter does not raise its evidence tier.
