# Simulator Lab V2 architecture freeze

Status: S2.0, S2.1, and S2.2 are implemented. S2.3 and S2.4 are not started in this document's implementation claims.

## Authority

Production Match Memory stays immutable Match Records. Projection stays disposable. D1 stays before a production Saved acknowledgement. Simulator research mode does not issue that acknowledgement.

Exactly one writable Match Authority. This program does not add a second writer.

Phone authority cutover: HOLD.

`research/watch_reference_ui` is the Flutter FORREF Watch Reference App used inside Simulator Lab. It is not the production SwiftUI, Wear Compose, Connect IQ, Zepp OS, or Huawei wearable binary.

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

`research/watch_reference_ui` depends on Flutter and `simulator_presentation`. It does not depend on `hf_v2`.

`research/hf_prototype` mounts `WatchReferenceApp` inside `DeviceShellStage` when a factual shell is open. The geometry stage remains available and still draws the Night I sporting targets so those tests stay intact. That stage is not the V2 device shell.

Not yet created:

- `research/simulator_sandbox`

Production packages do not depend on research packages. Research packages do not depend on `forref_match_core` or `forref_match_persistence`.

## Layers

The device profile describes facts. The viewport context describes a coordinate basis. A later shell describes hardware. A later aperture host clips the child. The selected runtime owns sporting truth. A later journal may observe that truth. None of those layers may impersonate another.

## Evidence stages

The simulator may compute PROFILED and, only with a linked shell manifest and aperture host, SIMULATION READY. It does not assign PLATFORM PROVEN or FORREF CERTIFIED. Imported JSON cannot set those stages.
