# Temporal authority — CLOCK-SLEEP-005

The 2500 ms window stays the admission rule. The 1 second pass and the 3–4 second failure are what that rule does when the last admitted sample is the foreground checkpoint.

Zepp documents `createSysTimer` as able to run while the screen is off. The 1.0.7 watch result does not show a callback inside the first 2500 ms of screen-off. Until the on-watch line shows `off>=1`, `max` at most 2500, and `r=TICK` or `r=CONTINUITY_RESUMED` for 3, 4, and 5 second sleeps, this firmware has not guaranteed that chain.

Sources that cannot fill the gap:

- The foreground `createTimer` is the screen-on sampler. It is not a screen-off clock.
- `Time.getTime()` is UTC. A missing callback does not create a sample, and the wall gap is not elapsed match time.
- `Time.onPerMinute` steps by about 60 seconds.
- One `@zos/alarm` at the end of the sleep is one late sample.
- Screen-on and screen-off edges mark the sleep. They do not fill it.
- No monotonic or boot-time counter is available in the device APIs this app uses.

Strategy, separate from this diagnostic and not implemented here:

Verified screen-off time needs a scheduler that is shown on this Bip 6 to fire and persist within 2500 ms of the last Device App checkpoint, and then to keep doing so. The witness line is the test for that claim. If 3, 4, and 5 second sleeps stay `off=0` or `max` above 2500, the platform limitation stands: this watch cannot continue verified match time across that sleep. The clock remains unverified. A later authority would be a new evidence source with its own tests, not a wider window on this UTC chain.
