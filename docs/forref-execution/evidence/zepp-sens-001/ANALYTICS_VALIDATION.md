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

## Session scope

`analyzeTrack(entries, sessionId)` keeps rows whose `sessionId` equals the argument. GNSS from another session cannot add distance or speed. Omitting the id returns `sessionScope: "SESSION_REQUIRED"`, an empty acceptance list, and distance 0. The track, status, and heat pages pass `latestSessionId`, the last non-empty id in the journal.

## Heart rate

`hrSampleRatio` is valid samples divided by heart-rate samples in that session. Valid means a finite BPM from 30 through 230. `hrTimeCoverage` is covered milliseconds divided by the session span. A valid sample covers time only until the next valid sample, and only up to 5,000 ms. The last sample adds no invented hold. If the session has no positive elapsed span, `hrTimeCoverage` is null and the watch shows `HR TIME UNMEASURED`. The sample ratio is never printed as a percentage.

## Distance sensor

`Distance` samples stay in `distanceSensorSamples`. Unit and attribution remain `UNRESOLVED`. `distanceSensorUsedInGnss` is false. A raw value of 9999 in the test is not added to the GNSS distance.

## Heat map

`buildHeatMap` projects accepted fixes into local meters from pitch corners `sw`, `se`, and `nw`, then into a 10 by 10 grid. Points outside `[0,1]` are out of bounds. Missing corners return `NO_CALIBRATION`. No accepted points return `NO_TRACK`. The watch heat page never calls this function and never supplies corners.

The synthetic test uses a pitch near latitude 0, longitude 0: southwest at the origin, southeast 105 m east, northwest 68 m north. That is not a venue.

## Test run

`npm test` in `apps/forref_sensor_lab` covers invalid and no-fix points, stationary drift, teleport, a 10-minute trace with a `DISPLAY_OFF` hole, an isolated spike, a sample ratio of 0.5 with time coverage 0, a 10-minute span whose time coverage stays under 2% while the sample ratio is 1, separate session distances, the unused distance sensor, the 90-minute storage refusal, and the synthetic heat map including `NO_TRACK` and `NO_CALIBRATION`.
