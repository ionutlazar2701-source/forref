# Founder protocol — 1.0.6 diagnostic

Install this build only when you choose to. It does not certify the watch. The 1.0.5 screen-sleep and capture-navigation failures stand until this protocol is run.

Record before kick-off: version 1.0.6, boot `build=clock-continuity-003 rev=9533f450f60b4443b74b1d5ba81ef65bbf2a1fb6`. Use a side-by-side stopwatch. Keep logs free of coordinates and heart-rate values.

1. Kick off with the screen on. Confirm `FORREF_CLOCK_FG timer=on` and a `src=fg` line whose `reason=TICK` and `readback` is not `READBACK`.
2. Open Goal, then a player, then Review. Stay on each page for at least 10 seconds. Do not return to Live in between. The log must keep `src=fg` ticks with `reason=TICK` on those pages, and `FORREF_LIFE player` / `review` must show `onInit` and `onDestroy`. When Live is visible again, the displayed time must match the stopwatch. Repeat once for a Card and once for a Substitution.
3. From a still-verified clock, turn the screen off for 5 seconds, then 30, then 120. On wake, the log needs `FORREF_CLOCK_SLEEP tick=` lines with `screen=off`, `readback=FILE_MIRROR`, and `last` moving forward. The displayed time must match the stopwatch.
4. Also record `perm=`, `request=`, `request-cb=`, `services=`, `start-code=`, and `start-cb=`. `services=absent` followed later by `services=restart` is a recovery, not by itself a pass. `services=gave-up` is a fail.
5. From a still-verified clock, pause. Frozen time must not grow. If the clock was already unverified before the whistle, say that; do not call it a new pause defect.

Stop on freeze, reboot, or dead input. A 90-minute run is out of scope. If step 2 or step 3 fails, the clock must show unverified time rather than a guessed elapsed.

QR expiry: 28 Nov 2026, 00:05:41 Europe/Bucharest (27 Nov 2026, 22:05:41 UTC). The preview log did not report a connected simulator.
