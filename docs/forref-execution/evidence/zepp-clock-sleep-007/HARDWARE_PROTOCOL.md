# Hardware protocol — timer creation

Device: Amazfit Bip 6. Install FORREF 1.0.10. Leave the foreground match clock as it is. Use a stopwatch.

Do not require an App Service file write to succeed while the screen is on. Do not treat `X` as match time.

1. Open the app and confirm the boot line contains `build=clock-sleep-007`.
2. Kick off and let the digits move.
3. Turn the screen off for exactly 5 seconds.
4. Wake the watch and copy the whole Live line. It is one short line: `T` `id` `D` `F` `X` `A` `b`.

Read the result from `CAUSE.md`. Stop on freeze, reboot, or dead input.

The preview log did not report a connected simulator.
