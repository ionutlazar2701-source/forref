# Founder protocol — 1.0.8 first five seconds

Install only when you choose to. This does not certify the watch. Goal, Card, Substitution, and Match Controls passed on 1.0.6. Leave that path as it is.

Do not ask the App Service to write a file while the screen is on. While the screen is on, read `S=` on the Live line and the log lines `service=on`, `timer=on`, `start-class=`, and `services=`. `pair=match` counts only on a `tick=` whose `screen=off`.

Record before kick-off: version 1.0.8, boot `build=clock-sleep-005 rev=3fdf956a515e31f76ded4625575d3925ded3c98f`. Use a stopwatch.

1. Kick off and leave the screen on for a few seconds. The Live line should show `S=ok` or `S=listed`. `off=0` is expected. `ck` should be a small number of milliseconds.
2. Turn the screen off, then wake, for each of 1, 2, 3, 4, and 5 seconds. After every wake, write the whole Live line: `S`, `off`, `max`, `ck`, and `r`.
3. Read it this way. At 1 and 2 seconds, `off=0` and `r=TICK` can still be a pass from the foreground checkpoint. At 3, 4, and 5 seconds, a pass needs `off` at least 1, `max` at most 2500, `ck` at most 2500, and `r=TICK` or `r=CONTINUITY_RESUMED`, with the displayed time matching the stopwatch. `off=0` at 3 seconds or more is a fail and means no background observation was committed. The clock must show unverified time, not a guessed elapsed time.

Stop on freeze, reboot, or dead input.

QR expiry: 28 Nov 2026, 00:50:04 Europe/Bucharest (27 Nov 2026, 22:50:04 UTC). The preview log did not report a connected simulator.
