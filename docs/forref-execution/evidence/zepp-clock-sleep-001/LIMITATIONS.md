# Limitations — clock sleep

Cloud result: the observation-chain model passes. Device continuity is not established. `CLOCK_SLEEP` on Amazfit Bip 6 is LOCAL GATE REQUIRED.

- There is no monotonic sleep-inclusive clock in the Zepp SDK. `Time.getTime()` is UTC. A single UTC delta across a screen-off gap is rejected.
- Exact time exists only while observations stay inside 2500 ms. Widening that window was not the fix.
- The App Service is the intended observer. It is unproven on Bip 6. Permission denial, a second continuous service, start codes other than success, a missed timer, or a failed off-screen write leave the clock unverified.
- `reload: false` means a reboot does not continue the sampler. The reboot gap stays unverified.
- `onPhoneTimeSetting` is logged and does not itself unverifiy. A UTC step outside 2500 ms, or a backward step, still fail-closes. The callback cannot separate a timezone change from a wall-clock change.
- The page and the service can both write. A newer running checkpoint is kept. A lost race still fail-closes rather than inventing the gap.
- Service file writes are documented only for screen-off or AOD. While the screen is on, the page timer is the observer.
- Wake relaunch reopens the mini program. It is not a time source.
- This clock is the watch prototype. It is not Match Memory and it does not change D1, temporal authority, or SQLite durability.
- The simulator was disconnected, so no on-screen preview was captured. The QR is an installable preview, not a field result.
- Native Familiarity V5 was not implemented. PR #52 and PR #53 were not modified.
