# Founder hardware protocol — clock sleep

Install only this candidate, and only when you choose to. Do not replace a build you are already testing until that test is finished. This package does not certify the watch.

Identity to record before kick-off:

- App 29566, version 1.0.4 (code 4), description `FORREF CLOCK SLEEP TEST BUILD`
- Boot line `build=clock-sleep-001 rev=f33bd669bfb7ff6764e278c3808a8c1c45f5d7b8`
- Package `29566-FORREF-1.0.4-20261120212010.zab`
- sha256 `c5818a59c16e7086e9beaac62c81ff4b102499c94a4a40a542f6123f8fe2014f`
- Side-by-side stopwatch. Note the background-service permission result and the `FORREF_CLOCK_SLEEP code=` line.

Then:

1. Kick off. Turn the screen off for 5 seconds. Wake. Compare the match clock with the stopwatch.
2. Repeat for 30 seconds and for 120 seconds. Use the natural screen timeout and, if the watch allows it, an explicit screen-off.
3. From Live, open Match Controls, wait more than 2.5 seconds, return to Live.
4. Pause, half-time, and the second half. Frozen phases must not gain elapsed time while the screen is off.
5. Separately: deny or revoke `device:os.bg_service`, stop the background service, and reboot the watch. Each of those must come back `TIME_UNVERIFIED` or `RECOVERY_REQUIRED`. They must not show invented time.

Logs to keep: `onCreate`, page build and destroy, service start code, tick or checkpoint, and trust. Do not record coordinates or heart-rate values. Note heat or input lag. A 90-minute run is out of scope. Stop if the watch freezes, reboots, or stops accepting input.

QR expiry from the Zeus preview clock: 27 Nov 2026, 23:20:13 Europe/Bucharest (21:20:13 UTC).
