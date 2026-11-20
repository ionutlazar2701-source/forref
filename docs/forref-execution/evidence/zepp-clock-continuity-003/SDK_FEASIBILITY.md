# SDK feasibility — CLOCK-CONTINUITY-003

Sources: Zepp OS App Service guide and the API 4.0 pages for `createSysTimer`, `queryPermission`, `requestPermission`, `start`, `stop`, `getAllAppServices`, and `getSettings`, as used by 1.0.5. The v1 `createTimer` page describes delay, repeat, and callback. It does not say a Device App timer keeps firing with the screen off. The newAPI `createTimer` URL returned 404 when checked for this change.

| Need | Contract used | Feasible in this build |
| --- | --- | --- |
| Sample during Goal / Card / Substitution | App `onCreate` outlives page `onDestroy`. A `createTimer` started there is not cleared by Live `onDestroy`. The Device App may write `@zos/fs` and `@zos/storage` while the screen is on. | Yes, for screen-on navigation. Not the screen-off clock. |
| Sample with the screen off | App Service `createSysTimer(true, 1000, cb)` is documented to run regardless of screen state. `@zos/fs` writes are allowed when the screen is off or AOD. | Implemented. Not shown on Bip 6 until `tick=` lines with `screen=off` appear. |
| Persist without LocalStorage | Service module imports only `@zos/fs` and `@zos/sensor`. Checkpoint is the file plus a mirror file. Readback requires both bytes to match. | Yes. LocalStorage remains the in-app copy when the Device App commits. |
| Restart a missing service | `getAllAppServices` empty while the host still believes it is running: the first empty list only logs. The second clears the flag and calls `start` again, at most three times, then `services=gave-up`. A thrown list does not count as absence. | Yes. A successful start on the same tick is not treated as absence. |
| Fail closed | `DISPLAY_CONTINUITY_MS` is 2500. No observation chain means `UNSAMPLED_GAP`. | Unchanged. |

`setWakeUpRelaunch({ relaunch: true })` and `start({ reload: false })` stay as in 1.0.5. Relaunch is not a time source. Reboot does not resume the sampler across the gap.

This is enough to ship a diagnostic build. It is not enough to certify elapsed time on Amazfit Bip 6.
