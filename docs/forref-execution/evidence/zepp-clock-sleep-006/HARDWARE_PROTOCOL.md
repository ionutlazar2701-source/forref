# Hardware protocol — one 5-second screen-off

Device: Amazfit Bip 6. Install FORREF 1.0.9 only. Leave 1.0.6 foreground behavior as it is. Use a stopwatch.

Do not require an App Service file write to succeed while the screen is on. A failed write while the screen is lit is an attempt, not a clock result. Do not ask for `pair=match` on a screen-on tick.

1. Open the app and confirm the boot line contains `build=clock-sleep-006 rev=3d7c4bc2f7a94f84a6e8b87f1796d45a3717a2a0`.
2. Kick off. Leave the match clock on screen until the digits are moving.
3. Cover or timeout the screen for exactly 5 seconds. Do not open another page.
4. Wake the watch and read the Live line immediately. Copy the whole line.

The line is:

`L=<link> r=<reason> n=<callbacks> x=<max dt> s=<screen> w=<attempts>/<ok>/<readback> I=<init> S=<start> D=<destroy> ck=<checkpoint age>`

| Line | First link |
| --- | --- |
| `L=SERVICE` `I=0` `n=0` | No durable init and no durable callback. `S=ok` does not change this |
| `L=TIMER` `I=1` `n=0` | Init was stored. No callback was stored |
| `L=WRITE` `n>=1` and the middle `w` value is 0 | A callback was counted and no write succeeded |
| `L=READ` and the last `w` value is 0 | A write succeeded and the readback did not match |
| `L=GAP` | A callback was stored and the chain was not inside 2500 ms. `x` is the largest callback spacing. `x=0` with `n=1` means one callback and no earlier callback to measure |
| `L=CHAIN` with `x` at most 2500 and `ck` at most 2500 | The stored callbacks were regular and a checkpoint was recovered |

`r` stays on the first temporal invalidation. A later `HELD` sample must not change it. `s` is `on`, `off`, `unk`, `unk:<number>`, or `fail`.

Stop on freeze, reboot, or dead input.

The preview log did not report a connected simulator.

QR expiry: 28 Nov 2026, 01:15:52 Europe/Bucharest (27 Nov 2026, 23:15:52 UTC).
