# Founder protocol — 1.0.5 diagnostic

Install this build only when you choose to. It does not certify the watch. The 1.0.4 screen-off results stand until this protocol is run.

Record before kick-off: version 1.0.5, boot `build=clock-sleep-002 rev=0b083a940b45943b6c0be5ee358005c572ac6ac5`, and the lines `perm=`, `request=`, `request-cb=`, `services=`, `start-code=`, `start-cb=`. Use a side-by-side stopwatch.

1. Kick off with the screen on for a few seconds. Confirm `timer=on` and at least one `tick=` with `screen=on` and a successful `readback`.
2. Screen off for 5 seconds. Wake. The log must contain `tick=` lines with `screen=off` whose `last` advanced, and the displayed time must match the stopwatch. Repeat for 30 seconds and 120 seconds.
3. From a still-verified clock, open Match Controls, wait more than 2.5 seconds, and return.
4. From a still-verified clock, pause, then end the first half. Record `intent=PAUSE` and `intent=END_FIRST_HALF`, the phase, and the trust. Frozen time must not grow. If the clock was already `TIME_UNVERIFIED` before the whistle, say that; do not call it a new pause defect.
5. Separately deny the background permission, and reboot. Expect `perm=denied` or `RECOVERY_REQUIRED`, not invented time.

Keep logs free of coordinates and heart-rate values. Stop on freeze, reboot, or dead input. A 90-minute run is out of scope.

QR expiry: 27 Nov 2026, 23:42:05 Europe/Bucharest (21:42:05 UTC).
