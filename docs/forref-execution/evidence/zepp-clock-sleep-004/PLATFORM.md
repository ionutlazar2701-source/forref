# Temporal source — CLOCK-SLEEP-004

Zepp OS API 4.0 documents `createSysTimer` as a system timer that can be registered in a device app service and runs regardless of screen state. The period argument is milliseconds. The published examples use 5000 ms and 10000 ms. The page does not state a minimum period, and it does not state that Bip 6 coalesces a 1000 ms timer past 2500 ms.

That is not a measurement. 1.0.6 already asked for this timer and the physical screen-off still became unverified, without a log of `dt`. 1.0.7 records `dt` and `screen` on every callback. Only a Bip 6 log can show whether the timer was silent or slower than 2500 ms.

Sources considered, and not used as elapsed time:

- `Time.getTime()` is UTC milliseconds. It is the observation clock already. It is not monotonic, and a callback that never arrives does not create a sample.
- `Time.onPerMinute` in the App Service example fires once a minute. A one-minute step is wider than 2500 ms, so it cannot continue verified match time.
- `@zos/alarm` wakes the service at a wall-clock time and runs a single execution. An alarm at the end of a 5, 30, or 120 second sleep is one sample after a gap. The gap stays unverified.
- Screen status from `getSettings` marks the off edge and the on edge. The time between those edges is the sleep. The edges do not fill it.
- No elapsed-realtime or boot-time counter is available in the device APIs this app uses. GPS and heart-rate timestamps are not the match clock.

If the 1.0.7 log shows `class=TIMER_GAP` or `TIMER_SILENT` while `service=on`, the platform did not deliver an observation chain inside 2500 ms. The clock stays unverified. The window is not widened, and no elapsed time is invented from the wall clock.
