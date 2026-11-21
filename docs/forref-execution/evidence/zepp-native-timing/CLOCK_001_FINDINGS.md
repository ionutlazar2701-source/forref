# CLOCK-001 — Native timing engine

Documentation verdict: **NO-GO**.
Hardware verdict: **NOT TESTED**.
Recommendation for a match-clock change: **NO-GO** until a physical report passes `reviewHardware`.
Baseline: `cursor/native-sport-feasibility-30fd` at `104bb21c4f28f6625273f9a8d7567669fbcee6f8`.
This branch does not modify that baseline, Match Core, Match Memory, or the officiating UI.

The hypothesis was that a FORREF Device App can read the elapsed duration the Amazfit Bip 6 Running app already measures, including while the screen is asleep, and translate a display such as `1:05:34` into referee time `65:34`. The target was a supported read after 10 minutes of screen sleep, without per-second JavaScript, within 1 second of an independent stopwatch.

That path is not in the public Zepp OS API. This document does not contain a duration measured on a watch.

## Evidence classes

| Class | What it means here |
| --- | --- |
| DOCUMENTED | A public Zepp OS page states the behavior. |
| SIMULATOR | Not run. No simulator duration is reported. |
| HARDWARE NOT TESTED | A watch procedure exists and has not been executed. This is not a measured failure. |
| PHYSICAL | A Bip 6 reading compared with an independent stopwatch. None is recorded. |

## Capability matrix

| Capability | Class | Result | Evidence |
| --- | --- | --- | --- |
| `getSportData({ type: "duration" })` | DOCUMENTED | Display string, not an elapsed type. Example `{"duration":"1:15:15","name":"Duration"}`. Callback `code` 0 is success. Permission `data:user.hd.workout`. API_LEVEL 3.6. | [getSportData](https://docs.zepp.com/docs/reference/device-app-api/newAPI/app-access/getSportData/) |
| Who may read that string | DOCUMENTED | The Workout Extension guide is the page that says `getSportData` obtains real-time data of the sports application. | [Quick start](https://docs.zepp.com/docs/guides/workout-extension/quick-start/) |
| Workout Extension on Bip 6 | DOCUMENTED | Unavailable. The intro lists Amazfit T-Rex 3, Cheetah Pro, Cheetah (Round), Cheetah Square, T-Rex Ultra, and Falcon. Bip 6 is absent. API_LEVEL 4.2 does not add a device to that list. | [Intro](https://docs.zepp.com/docs/guides/workout-extension/intro/) |
| Extension focus | DOCUMENTED | `onPause` keeps context, stops registered callbacks, and pauses registered timers. That is the opposite of a sleep-proof reader. | Same quick start |
| `SPORT_DATA` `DURATION_NET` | DOCUMENTED | A widget draws exercise time inside a Workout Extension. `mock_data` is emulator-only. The widget does not return the number to script. | [SPORT_DATA](https://docs.zepp.com/docs/reference/device-app-api/newAPI/ui/widget/SPORT_DATA/) |
| `Workout` sensor | DOCUMENTED | Methods are `getStatus`, `getHistory`, `getUserHrZoneSettings`, and `getWorkoutTrackNavInfo`. There is no start, pause, resume, or live duration method. | [Workout](https://docs.zepp.com/docs/reference/device-app-api/newAPI/sensor/Workout/) |
| `getHistory().duration` | DOCUMENTED | Whole seconds on a stored workout record, with `startTime`. A finished record is not a running stopwatch. | Same Workout page |
| System Stopwatch / Workout | DOCUMENTED | `SYSTEM_APP_STOPWATCH`, `SYSTEM_APP_SPORT`, and `SYSTEM_APP_SPORT_HISTORY` are jump identifiers. `checkSystemApp` returns void. | [checkSystemApp](https://docs.zepp.com/docs/reference/device-app-api/newAPI/router/checkSystemApp/) |
| `Time.getTime()` | DOCUMENTED | UTC milliseconds. No monotonic, boot, or elapsed method is listed. Wall-clock subtraction is outside this mission. | [Time](https://docs.zepp.com/docs/reference/device-app-api/newAPI/sensor/Time/) |
| `createSysTimer` | DOCUMENTED | API_LEVEL 4.0. Registers a callback in a Device App Service and is documented to run regardless of screen state. The return value is a timer id. A callback count is not elapsed duration. | [createSysTimer](https://docs.zepp.com/docs/reference/device-app-api/newAPI/timer/createSysTimer/) |
| App Service timers | DOCUMENTED | Global timer interfaces such as `setTimeout` are unavailable. High-power sensors are forbidden. `@zos/app-access` is not in the published availability table. | [App Service](https://docs.zepp.com/docs/guides/framework/device/app-service/) |
| Sleep-proof OS elapsed read for a standalone app | DOCUMENTED | No such method is published. This is the documentation NO-GO. | This file |
| `getSportData` from standalone app id 30102 while Running is active | HARDWARE NOT TESTED | DUR-001 is built and previewed. No callback, permission code, or error from a watch is recorded. | `CLOCK_001_HARDWARE_TEST.md` |
| Simulator duration | SIMULATOR | Not run. No guest callback was captured. | — |
| Physical error against a stopwatch | PHYSICAL | Not measured. | — |

## What the public pages do not provide

The documentation NO-GO is this section. It is not a watch result.

A public page does not give a normal Device App on Bip 6 a call that returns the Running app's elapsed duration.

- Opening Stopwatch or Workout only checks that a system app can be launched.
- The Workout sensor does not control the Running session and does not expose its live timer.
- `getSportData` is a public function, and its duration value is a formatted string from the sports application. The guide that describes that read is the Workout Extension, which Bip 6 cannot host on the published device list.
- The same extension pauses its timers when the page loses focus.
- `createSysTimer` can wake script. It does not measure time. Using its callbacks as seconds would repeat the model this mission excludes.
- `Time.getTime()` moves when the civil clock moves. It is not the Running app's stopwatch.
- No public page documents `elapsedRealtime`, a monotonic boot clock, or a third-party read of an OS stopwatch.

The `getSportData` reference page also contains a paragraph about a Mini Program exiting about 10 seconds after the screen turns off. That paragraph describes process exit and optional relaunch. It does not describe an elapsed-time source.

## Translation is not authority

The documented example `1:15:15` parses as 4,515 seconds and would display as referee `75:15`. The founder's example `1:05:34` parses as 3,934 seconds and displays as `65:34`. The parser accepts only `H:MM:SS` with minutes and seconds in `00`–`59`, because that is the shape in the API example. `65:34`, `1:5:34`, and `1:15` are rejected.

A successful parse is still `TIME_UNKNOWN`. The string has no documented epoch, pause rule, or error bound. FORREF does not promote it to `PROVEN_TIME`.

## Installable probe

`apps/forref_duration_probe` is a separate Device App. It is not production FORREF and it is not the sensor lab.

| Field | Value |
| --- | --- |
| Name | DUR-001 |
| App id | 30102 |
| Version | 1.0.0, code 1 |
| Permission | `data:user.hd.workout` |
| Call | `getSportData({ type: "duration" }, callback)` |
| Package | `30102-DUR-001-1.0.0-20261121095858.zab` |
| sha256 | `b975d73592e5233dff531afcccb91a5d13353feadfdecd9c4bc0457212d713e5` |
| Size | 11332 bytes |
| QR expiry | 28 Nov 2026, 11:58:59 Europe/Bucharest (09:58:59 UTC) |

`queryPermission` is synchronous and returns an array: `0` not authorized, `1` unknown, `2` authorized. `requestPermission` returns `0` while the prompt is in progress, `1` when there is nothing to request, and `2` when the permission is already authorized. Its callback receives the array. `getSportData` returns a boolean immediately. The duration arrives only in the later callback. A return of `true` with no callback yet is `CALLBACK_PENDING`. If the callback is still absent after 10 seconds, the screen reason becomes `NO_CALLBACK_10S`. That means the callback had not arrived. It is not an OS error code.

The screen keeps `TIME_UNKNOWN` when a duration string is shown. Production app id 29566 and sensor lab app id 30101 do not declare `data:user.hd.workout` and do not call `getSportData`.

`reviewHardware` ignores a report that asserts `measured`, `proven`, `absErrorMs`, `pauseResume`, or `javascriptTicksUsed`. A passing report must name probe `DUR-001` 1.0.0, a Bip 6 device source (`9765120`, `9765121`, or `10158337`), and one `getSportData` read for each required step. Each read carries `permission: 2`, `accepted: true`, `code: 0`, and the callback `raw` string. Sleep errors are computed from that string and `stopwatchSeconds`. The repository has no physical report. The automated accept case is a gate fixture.

## Recommendation

Documentation: **NO-GO**. The published API does not define a sleep-proof elapsed duration for this app.

Hardware: **NOT TESTED**. DUR-001 is the experiment. No permission code, callback code, or duration from a Bip 6 is in this repository. Do not treat the missing measurement as proof that the call fails, and do not treat the package build as proof that it succeeds.

A match clock stays on its existing observation chain. This branch does not change that chain.

## Checks

Sensor lab plus the probe: 45 tests passed. `./tool/verify_cloud.sh` passed: match core 377, persistence 92, phone 126. Those runs do not measure a watch. Simulator: not run. Physical: not measured.
