# Device shell contract

`DeviceShellManifest` is procedural. Schema version 1 of the manifest is separate from device profile schema v1 and v2.

## Required fields

profileId, manifestVersion, canvas size and unit, body bounds, optional strap bounds, display aperture, clip, corner radius with a measured flag, control anchors, representation kind, visual fidelity, asset provenance, aperture evidence.

Representation used in S2.1: `procedural`.

Fidelity used in S2.1: `schematic`.

No seed shell is `measured` or `verifiedAgainstReference`. No manufacturer bitmap is committed.

## How a shell is chosen

`shellManifestFor` reads facts:

- Known case millimetres and a round shape produce a round case. If a display diagonal is known, the circle diameter is that diagonal converted at 25.4 mm per inch. The caption says the aperture is not measured.
- Known case millimetres and a rounded-rectangle shape produce a rounded case with a 2.4 mm schematic inset. The corner radius is 16 percent of the shorter side and `cornerRadiusMeasured` is false.
- Unknown case millimetres with a known design-coordinate aspect produce an aspect shell. The unit is not millimetres.
- Otherwise the shell is a plate. It does not invent a watch silhouette. Garmin Approach S60 takes this path because its case and display facts are unknown.

Control anchors are drawn only for supported crown or physical-key facts. Their coordinates are a right-side convention. `simulatedChannel` stays false unless the profile sets `appMaySimulate`.

## Hit surfaces

`shellSurfaceAt` returns aperture, bezel, strap, control, or outside.

The aperture is the only display surface. Bezel, strap, control marks, and the square corners of a round case are not the display.

## Evidence stage

Shell manifests do not change `profileV2EvidenceStage`. Seed profiles stay PROFILED. A schematic aperture is not SIMULATION READY and not a safe area.

## Widget host

`DeviceShellStage` paints the manifest and mounts its child in the aperture through a clip. The shell paint does not receive the child's button hits. A profile id change cancels pointers that were down.

The lab selector opens a factual profile with `openDeviceShell`. That cancels open research pointers and does not append a record.
