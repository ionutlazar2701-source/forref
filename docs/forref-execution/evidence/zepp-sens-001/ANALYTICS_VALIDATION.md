# Analytics validation

`apps/forref_sensor_lab/lib/analytics.js` is pure. It does not import `@zos`. Results carry `experimental: true`, `certifiedDistance: false`, `certifiedSpeed: false`, and `medicalInterpretation: false`. The heart-rate note is `NOT_A_HEALTH_DIAGNOSIS`.

## Distance and speed

- Haversine, Earth radius 6,371,000 m.
- Status other than `A`, invalid coordinates, duplicate fixes, null elapsed (`UNKNOWN_TIME`), and non-positive elapsed (`NON_POSITIVE_TIME`) are discarded.
- Movement under 4 m is accepted and adds 0 m (`STATIONARY`).
- Speed above 12 m/s discards the point as `TELEPORT` and keeps the previous fix. It is not a maximum speed.
- A segment faster than 6 m/s that is alone, or faster than 6 m/s and more than twice both neighbors, is a spike. Spikes are excluded from distance and from maximum speed.
- Maximum speed needs a segment of at least 1,000 ms. If none qualify, maximum speed is null.
- A gap is recorded when elapsed jumps by more than 15,000 ms. The missing meters are not interpolated.
- `SCREEN_OFF_OR_PAUSE` is used only when a `DISPLAY_OFF` or `PAUSE` lifecycle sits between the GNSS samples. Otherwise the reason is `STALL`.
- A reversed diagnostic clock is `RESTART_UNMEASURED` with `missingMs` null.

## Distance sensor

`Distance` samples stay in `distanceSensorSamples`. Unit and attribution remain `UNRESOLVED`. `distanceSensorUsedInGnss` is false. A raw value of 9999 in the test is not added to the GNSS distance.

## Heat map

`buildHeatMap` projects accepted fixes into local meters from pitch corners `sw`, `se`, and `nw`, then into a 10 by 10 grid. Points outside `[0,1]` are out of bounds. Missing corners return `NO_CALIBRATION`. No accepted points return `NO_TRACK`. The watch heat page never calls this function and never supplies corners.

The synthetic test uses a pitch near latitude 0, longitude 0: southwest at the origin, southeast 105 m east, northwest 68 m north. That is not a venue.

## Test run

`npm test` in `apps/forref_sensor_lab`: 15 passed, 0 failed. The analytics file covers invalid and no-fix points, stationary drift, teleport, a 10-minute trace with a `DISPLAY_OFF` hole, an isolated spike, heart-rate coverage 0.5, the unused distance sensor, and the synthetic heat map including `NO_TRACK` and `NO_CALIBRATION`.
