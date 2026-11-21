# CLOCK-001 — Native timing engine

Status: research complete on public APIs. No physical measurement exists.
Recommendation: **NO-GO**.
Baseline: `cursor/native-sport-feasibility-30fd` at `104bb21c4f28f6625273f9a8d7567669fbcee6f8`.
This branch does not modify that baseline, Match Core, Match Memory, or the officiating UI.

The hypothesis was that a FORREF Device App can read the elapsed duration the Amazfit Bip 6 Running app already measures, including while the screen is asleep, and translate a display such as `1:05:34` into referee time `65:34`. The target was a supported read after 10 minutes of screen sleep, without per-second JavaScript, within 1 second of an independent stopwatch.

That path is not in the public Zepp OS API. This document does not contain a duration measured on a watch.

## Evidence classes

| Class | What it means here |
| --- | --- |
| DOCUMENTED | A public Zepp OS page states the behavior. |
| SIMULATOR | Not run. No simulator duration is reported. |
| HARDWARE_PENDING | A watch procedure exists and has not been executed. |
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
| Standalone Bip 6 read after 10 minutes asleep | HARDWARE_PENDING | No supported public path. A watch trial cannot create an API the docs do not provide. | This file and the hardware protocol |
| Simulator duration | SIMULATOR | Not run. | — |
| Physical error against a stopwatch | PHYSICAL | Not measured. | — |

## What a standalone app cannot do

A normal Device App on Bip 6 has no documented call that returns the Running app's elapsed duration.

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

## Isolated probe

`apps/forref_sensor_lab/lib/native_elapsed.js` is a pure diagnostic. It does not import `@zos`, does not request `data:user.hd.workout`, and is not referenced by the lab UI or the match app. `readSportDuration` accepts an injected reader so the callback contract can be tested. Every sport, history, system-timer, wall-clock, and system-app result returns `TIME_UNKNOWN`.

`reviewHardware` can return `PROVEN_TIME` only for a caller-supplied report that names a physical Bip 6, covers 30-second, 2-minute, and 10-minute sleep, records repeated wakes, reopen, Bluetooth disconnection, and pause/resume, does not use JavaScript ticks as the source, and stays within 1,000 ms. The repository contains no such report. The automated accept case is a gate fixture, not a watch result.

Sensor lab app id remains 30101. Production app id remains 29566. Neither manifest gains `data:user.hd.workout`.

## Recommendation

**NO-GO** for reading the Bip 6 Running duration from FORREF.

Reopen only if all of the following become true:

1. A public Zepp page documents a Bip 6 Device App, or a Bip 6 Workout Extension, reading an OS-managed elapsed duration.
2. That read is specified to survive screen sleep without per-second JavaScript execution.
3. A physical protocol in `CLOCK_001_HARDWARE_TEST.md` records every required interval within 1,000 ms of an independent stopwatch.

Until then, match time stays fail-closed: `PROVEN_TIME` only from an accepted observation chain, and `TIME_UNKNOWN` when that chain breaks. This research does not change that chain.

## Checks

Sensor lab: 40 tests passed, including the new elapsed probe. `./tool/verify_cloud.sh` passed: match core 377, persistence 92, phone 126. Those runs do not measure a watch. Simulator: not run. Physical: not measured.
