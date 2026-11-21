# CLOCK-001 — Physical validation

The founder observed on a physical Amazfit Bip 6 that an active Running workout blocks other apps. Concurrent Running plus DUR-001 is not the primary experiment. Stopwatch research is `CLOCK_002_FINDINGS.md`.

Hardware verdict: **NOT TESTED**.
Documentation verdict: **NO-GO** for treating a public API as a sleep-proof elapsed clock. See `CLOCK_001_FINDINGS.md`.
This file is the procedure. Every result cell stays empty until a person copies it from a watch. Do not estimate a cell.

## Install

1. Use the Zepp app on the phone paired to the physical Amazfit Bip 6. Developer mode is on.
2. Scan the QR in `PREVIEW_QR.txt`. It is DUR-001 1.0.0, app id `30102`, and it expires 28 Nov 2026, 11:58:59 Europe/Bucharest (09:58:59 UTC).
3. Confirm the watch shows DUR-001. Production FORREF is app id `29566`. The sensor lab is app id `30101`. This package does not replace either one.
4. Package that matches the QR: `30102-DUR-001-1.0.0-20261121095858.zab`, sha256 `b975d73592e5233dff531afcccb91a5d13353feadfdecd9c4bc0457212d713e5`, 11332 bytes. The file is gitignored.

An independent stopwatch, not the watch, is the comparison clock. Start it only when the procedure says so.

## What the screen means

| Line | Meaning |
| --- | --- |
| Permission | First number from `queryPermission` or from the request callback. `0` not authorized, `1` unknown, `2` authorized. `PERMISSION_SHAPE` means the call did not return that array. |
| Request | Immediate `requestPermission` result, then the callback value. Immediate `0` is a prompt in progress, `1` means nothing to request, `2` means already authorized. |
| Call | `1` if `getSportData` returned `true`. `0` if it returned anything else. `-` if it has not been called. |
| Code | Callback `code`. `0` is the documented success code. Any other number is the API result. `-` means no callback yet. |
| Duration | Clock text taken from a successful payload, or `-`. |
| State | `TIME_UNKNOWN`, then a reason. `CALLBACK_PENDING` means the call was accepted and the callback has not arrived. `NO_CALLBACK_10S` means it was still absent after 10 seconds. That is not an OS error code. A shown referee time such as `65:34` is still `TIME_UNKNOWN`. |

If the watch is connected to a log, also copy the `DUR001` line. `raw=` is the callback string, truncated to 80 characters. `source=` on boot is the device source.

## Concurrent Running session

Do this before the sleep rows. Leave the result blank if the watch will not keep Running open behind DUR-001. That blank is the concurrency observation. Do not fill it with a guess.

1. Start the system Running workout and let the native duration advance.
2. Open DUR-001 without stopping Running.
3. Copy the Permission line.
4. Tap REQUEST PERMISSION. Copy the Request line and the new Permission line.
5. Tap READ DURATION. Wait until State changes, or until it shows `NO_CALLBACK_10S`.
6. Copy all six lines and, if present, the `DUR001` log line.

| Step | Copied screen | Result |
| --- | --- | --- |
| Running active, first paint | | NOT TESTED |
| After REQUEST PERMISSION | | NOT TESTED |
| After READ DURATION | | NOT TESTED |

## Sleep, wake, reopen, Bluetooth, pause

Repeat READ DURATION at the comparison moment. Copy the six lines and the independent stopwatch.

| Id | What to do | Copied screen | Stopwatch | Result |
| --- | --- | --- | --- | --- |
| H30 | Screen off for 30 seconds, then read. | | | NOT TESTED |
| H120 | Screen off for 2 minutes, then read. | | | NOT TESTED |
| H600 | Screen off for 10 minutes, then read. | | | NOT TESTED |
| H-WAKE | During H600, wake and sleep three times. Read after each wake. | | | NOT TESTED |
| H-REOPEN | Leave Running and DUR-001, open DUR-001 again, read. | | | NOT TESTED |
| H-BT | Phone Bluetooth off for at least 30 seconds, then on. Read before, during, and after. | | | NOT TESTED |
| H-PAUSE | Pause Running, wait 30 seconds, resume, read after the pause and after the resume. | | | NOT TESTED |

## When a report can pass the gate

`reviewHardware` in `apps/forref_sensor_lab/lib/native_elapsed.js` accepts a report only when the transcribed reads include:

- `probe: "DUR-001"`, `version: "1.0.0"`, and `deviceSource` `9765120`, `9765121`, or `10158337`
- for every read: `api: "getSportData"`, `type: "duration"`, `permission: 2`, `accepted: true`, `code: 0`, and the callback `raw` string
- sleep reads at 30, 120, and 600 seconds, each with `stopwatchSeconds` from the independent stopwatch
- at least three `wake` reads, one `reopen`, one `bluetooth`, one `pause`, and one `resume`

The error is computed from the duration string inside `raw` and the stopwatch. A field named `measured`, `proven`, `absErrorMs`, `pauseResume`, or `javascriptTicksUsed` rejects the report. No report in this repository meets the shape.
