# Simulator Lab V2 architecture freeze

Status: S2.0 implemented. Later waves are not started in this document's implementation claims.

## Authority

Production Match Memory stays immutable Match Records. Projection stays disposable. D1 stays before a production Saved acknowledgement. Simulator research mode does not issue that acknowledgement.

Exactly one writable Match Authority. This program does not add a second writer.

Phone authority cutover: HOLD.

The Flutter watch reference app, when it exists, is a simulator reference. It is not the production SwiftUI, Wear Compose, Connect IQ, Zepp OS, or Huawei wearable binary.

## Package DAG

Implemented in S2.0:

```
research/simulator_geometry
research/simulator_presentation
research/hf_v2
        │
        ▼
research/simulator_hf_bridge
```

`simulator_geometry` and `simulator_presentation` do not depend on each other. The bridge depends on both and on `hf_v2`. `hf_v2` does not depend on the bridge.

Not yet created:

- `research/watch_reference_ui`
- `research/simulator_sandbox`

`research/hf_prototype` can open a factual shell. The child is still the diagnostic viewport. The watch reference app is not mounted.

Production packages do not depend on research packages. Research packages do not depend on `forref_match_core` or `forref_match_persistence` in S2.0.

## Layers

The device profile describes facts. The viewport context describes a coordinate basis. A later shell describes hardware. A later aperture host clips the child. The selected runtime owns sporting truth. A later journal may observe that truth. None of those layers may impersonate another.

## Evidence stages

The simulator may compute PROFILED and, only with a linked shell manifest and aperture host, SIMULATION READY. It does not assign PLATFORM PROVEN or FORREF CERTIFIED. Imported JSON cannot set those stages.
