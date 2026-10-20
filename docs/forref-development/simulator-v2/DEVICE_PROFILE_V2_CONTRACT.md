# Device profile v2 contract

Schema version 2 lives beside schema version 1. `parseProfile` still accepts only version 1. `parseProfileV2` accepts only version 2.

## Fact status

`known`, `unknown`, and `derived`.

An `EvidenceFact` carries status, value, sourceIds, derivation, and uncertainty.

- Unknown value must be absent or null. Zero is rejected.
- Known and derived values need at least one source id that exists in `sources`.
- Derived values need a non-empty derivation.
- Known values must not carry a derivation.
- Positive measurements must be greater than zero. Zero is not known-none.

## Identity

`profileId` is a lowercase hyphenated simulator id. Manufacturer, family, model, variant, and platform family are facts. `deviceClass` is the simulator taxonomy `phone` or `smartwatch`. It is not a manufacturer measurement.

## Display

Native logical viewport, design coordinate space, and raster are separate facts. A design benchmark or a raster fallback must not be labeled a native logical viewport.

Safe area and shell aperture use the same evidence rule. Unknown safe area has no inset object. The viewport context sets `safeAreaKnown` false and does not invent insets.

## Controls

Availability is `supported`, `unsupported`, `unknown`, or `systemReserved`.

`appMaySimulate` may be true only when availability is supported. Supported does not require `appMaySimulate`.

Unknown is not recorded as unsupported.

## Evidence stage

`profileV2EvidenceStage` is computed. Profile JSON is rejected if it contains certification, platform-proven, or evidence-stage fields.

A known aperture value is not enough for SIMULATION READY. The caller must also link a shell manifest and an aperture host. S2.0 seed profiles stay PROFILED.

## Viewport basis

Order:

1. Native logical width and height, when both are known or derived.
2. Design coordinate width and height.
3. Raster width and height, labeled raster fallback.
4. Unavailable. Width and height stay null.

Width and height are never mixed across bases.
