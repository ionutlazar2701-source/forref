# Limitations — clock sleep 002

- The 1.0.4 Bip 6 screen-off checks failed. This repair makes the documented start path reachable. It does not prove `createSysTimer` runs during screen-off on that watch.
- `requestPermission`'s callback array is interpreted with the same codes as `queryPermission` (`0`, `1`, `2`). The request page names the callback as an array and does not restate those three codes.
- `getAllAppServices` is logged. An empty list after a successful start is logged as `services=absent` and does not by itself clear the local running flag, so a dead service is not restarted every second.
- A committed pause wins over a newer running service image. The extra service second after the whistle is dropped.
- `DISPLAY_CONTINUITY_MS` is still 2500. A gap with no observation stays unverified.
- `reload: false` still means a reboot does not continue the sampler.
- The simulator was disconnected. The QR is an install package, not a field result.
- PR #52, PR #53, and PR #54 were not rewritten. Native Familiarity V5 was not implemented.
