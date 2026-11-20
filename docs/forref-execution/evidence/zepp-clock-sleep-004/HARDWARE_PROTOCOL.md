# Founder protocol — 1.0.7 screen-off evidence

Install only when you choose to. This does not certify the watch. Goal, Card, Substitution, and Match Controls already passed on 1.0.6. Repeat one of them only if the clock looks wrong before the screen goes off.

Record before kick-off: version 1.0.7, boot `build=clock-sleep-004 rev=5e31b2402f1fda1e7a171b8628ebff2248089b29`. Use a stopwatch. Keep coordinates and heart-rate values out of the notes.

1. Kick off with the screen on for a few seconds. Confirm `service=on timer=on` and one `tick=` with `screen=on`, `class=CHAIN`, and `pair=match`. Also note `perm=`, `start-class=`, and `services=`.
2. Turn the screen off for 5 seconds. Wake. Copy every `tick=` with `screen=off`, the `edge=off` and `edge=on` lines, and the `recover=` line if the app opened again. The displayed time must match the stopwatch for a pass. Repeat for 30 seconds and for 120 seconds.
3. Write the one label from `CHAIN.md`: `SERVICE`, `TIMER_CREATE`, `TIMER_SILENT`, `TIMER_GAP`, `PERSIST`, `RECOVERY`, or `CHAIN`.
4. If you pause, `stop-reason=phase` is expected and the frozen time must not grow. `stop-reason=unverified` means the clock was already unverified before the whistle.

A pass is `class=CHAIN`, `pair=match`, `dt` at most 2500, `screen=off` during the sleep, and `recover=CONTINUITY_RESUMED` or a still-verified clock that matches the stopwatch. Anything else is a fail. Do not treat the displayed gap as verified time.

Stop on freeze, reboot, or dead input.

QR expiry: 28 Nov 2026, 00:32:25 Europe/Bucharest (27 Nov 2026, 22:32:25 UTC). The preview log did not report a connected simulator.
