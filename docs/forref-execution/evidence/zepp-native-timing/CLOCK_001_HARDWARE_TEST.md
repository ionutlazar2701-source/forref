# CLOCK-001 — Hardware protocol

Status: **LOCAL GATE REQUIRED**. No row below has been run.
Device: Amazfit Bip 6, with an independent stopwatch that is not the watch.
Error budget: absolute difference at most 1,000 ms at the moment of comparison.
This protocol does not authorize a match-clock change. A pass would only be evidence for a later decision.

## Before any trial

1. Record the FORREF package under test, or record that the trial uses the system Running app alone.
2. Do not treat a simulator, a callback count, or `Time.getTime()` as the native duration.
3. Leave the result blank when a step is skipped. Do not estimate it.
4. Copy the on-screen duration string exactly, including colons.

The public API does not give a standalone FORREF app a duration to read on this device. If the trial is the system Running app alone, label the source `SYSTEM_RUNNING_SCREEN`. If a later public API is being probed, label the source with the API name and the permission prompt result. A missing permission is a failed read, not a duration of zero.

## Rows

| Id | Setup | Sleep or interruption | Record | Result |
| --- | --- | --- | --- | --- |
| H30 | Start the source and the independent stopwatch together. Confirm both are running. | Screen off for 30 seconds. | Source string, stopwatch, absolute error, screen state. | HARDWARE_PENDING |
| H120 | Same start. | Screen off for 2 minutes. | Same fields. | HARDWARE_PENDING |
| H600 | Same start. | Screen off for 10 minutes. | Same fields. This is the success interval. | HARDWARE_PENDING |
| H-WAKE | During H600, wake and sleep the screen three times without stopping the source. | Repeated wake. | Duration immediately after each wake, and whether it jumped or froze. | HARDWARE_PENDING |
| H-REOPEN | Leave the source running. Leave the app and open it again on the same session. | App reopen. | Duration before leaving and after reopening. | HARDWARE_PENDING |
| H-BT | Disable phone Bluetooth for at least 30 seconds, then enable it. | Bluetooth disconnection. | Duration before, during, and after. | HARDWARE_PENDING |
| H-PAUSE | Pause the source, wait 30 seconds, resume. | Pause and resume. | Whether the paused interval was excluded, and the error after resume. | HARDWARE_PENDING |

## Acceptance

A report can be reviewed by `reviewHardware` in `apps/forref_sensor_lab/lib/native_elapsed.js` only when it includes:

- `measured: true`, `device: "Amazfit Bip 6"`, `source: "PHYSICAL_BIP6"`
- `javascriptTicksUsed: false`
- repeated wakes, reopen, Bluetooth drop, and pause/resume all completed
- one absolute error for 30, 120, and 600 seconds of screen sleep
- the worst of those errors at most 1,000 ms

No report in this repository meets that shape. Do not fill one in from a cloud run.
