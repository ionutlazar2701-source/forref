# Native sports engine feasibility

Retrieved 18 Nov 2026 from the public Zepp OS docs. This probe does not call those APIs on a watch, does not add `data:user.hd.workout`, and does not change the SENS V2 sensor controller lifecycle. PR #49 stays unmerged.

Sources:

- [getSportData](https://docs.zepp.com/docs/reference/device-app-api/newAPI/app-access/getSportData/)
- [Workout Extension intro](https://docs.zepp.com/docs/guides/workout-extension/intro/)
- [Workout Extension quick start](https://docs.zepp.com/docs/guides/workout-extension/quick-start/)
- [Distance](https://docs.zepp.com/docs/reference/device-app-api/newAPI/sensor/Distance/)
- [SPORT_DATA](https://docs.zepp.com/docs/reference/device-app-api/newAPI/ui/widget/SPORT_DATA/)
- [Workout](https://docs.zepp.com/docs/reference/device-app-api/newAPI/sensor/Workout/)
- [Device list](https://docs.zepp.com/docs/reference/related-resources/device-list/)

## Capability matrix

| Metric | Availability | Why |
| --- | --- | --- |
| Native distance, speed, and duration through `getSportData` | EXTENSION_ONLY | The quick start lists `getSportData` with Workout Extension and says it reads real-time sports-app data. The documented types include `distance`, `speed`, and `duration`. The sample values are strings such as `"9.99"` and `"1:15:15"`. No unit is specified, so a parsed string is not meters. |
| Those three metrics inside an independent Device App on a physical Bip 6 | HARDWARE_PENDING | The API page requires `data:user.hd.workout` and API_LEVEL 3.6. It does not document a standalone Device App session. This build does not call the function. |
| Workout Extension on Bip 6 | UNAVAILABLE | The intro lists Amazfit T-Rex 3, Cheetah Pro, Cheetah (Round), Cheetah Square, T-Rex Ultra, and Falcon. Bip 6 is not in that list. The device list shows Bip 6 at API_LEVEL 4.2 and Zepp OS 5.0 (`9765120`, `9765121`, `10158337`). That level does not add the watch to the extension list. |
| `Distance.getCurrent()` | AGGREGATE_ONLY | API_LEVEL 2.0, permission `data:user.hd.distance`. The method returns a number. The docs do not state the unit, whether it is today's total or a workout, or a session id. `getDistanceUnit` is the user's display preference and explicitly is not the data unit. It is not native workout distance and stays out of the GNSS total. |
| Native maximum speed as a value JavaScript can read | UNAVAILABLE | `getSportData` documents `speed` and `avg_speed`. It does not document a maximum-speed type. |
| `SPORT_DATA` `SPEED_MAX` | EXTENSION_ONLY | The widget page says it displays workout data in the workout extension. `SPEED_MAX` is a display type. The widget does not return the number to script. Bip 6 is not on the extension device list, so this display is not an integration path for that watch. |
| Full GPS track | UNAVAILABLE | No reviewed public call returns the workout polyline. `getWorkoutTrackNavInfo` (API_LEVEL 4.2) returns update, yaw, remaining distance, and the next turn while navigation is enabled. That is not a track. `Geolocation` returns the current WGS-84 fix. |
| Native Outdoor Walking versus FORREF experimental distance on a known route | HARDWARE_PENDING | Not run. No totals are filled in. |

Labels are only `NATIVE_DIRECT`, `EXTENSION_ONLY`, `AGGREGATE_ONLY`, `UNAVAILABLE`, and `HARDWARE_PENDING`. Nothing in this matrix is `NATIVE_DIRECT`.

## Stationary filter

`measureSegment` keeps the last accepted anchor when a step is under 4 meters. The old loop stored that short step as the new anchor, so a walk made of 3 meter fixes added 0. A straight 12 meter walk in 3 meter fixes now totals about 12 meters. Jitter that stays inside 4 meters of the anchor still adds 0. A jump faster than 12 m/s still does not move the anchor. The tail shorter than 4 meters is not added until a later fix clears the threshold. Experimental distance remains uncertified.

## Recommended architecture for Bip 6

Keep SENS V2 as the only on-watch capture path. Heart rate and GPS stay independent, and experimental distance stays the bounded GNSS sum with the held anchor. Do not add a Workout Extension, do not request `data:user.hd.workout`, and do not copy `Distance.getCurrent()` into that sum.

On a device that is named in the Workout Extension intro, a later extension would be a separate app id. It could display native distance, speed, and duration with `getSportData` or `SPORT_DATA`. It would not write Match Memory, and it would not be built for Bip 6 while the official list omits that watch.

Do not invent maximum speed or a route from `getWorkoutTrackNavInfo`. A known-route comparison is a founder measurement: record the native Outdoor Walking total, repeat the same measured path with SENS experimental distance, and compare the two totals. Do not publish coordinates or a pulse value. Until that comparison exists, native and experimental distances are not interchangeable.

## Verified versus not run

Verified from the docs and from the unit tests: the extension device list, the `getSportData` field list, the missing maximum-speed and track fields, the unresolved distance sensor, and the 3 meter walking regression.

Not run: any physical Bip 6 call to `getSportData`, any Workout Extension install, and any Outdoor Walking comparison.
