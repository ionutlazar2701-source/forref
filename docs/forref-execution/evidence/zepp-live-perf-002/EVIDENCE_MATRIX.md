# Live Match performance integration 002

Stack tip verified before this branch: `104bb21c4f28f6625273f9a8d7567669fbcee6f8` on `cursor/native-sport-feasibility-30fd`.

Ancestry, all unmerged: PR #51 → PR #49 → PR #48 → PR #44 (`cursor/zepp-live-match-flow-002-30fd`) → `cursor/zepp-match-clock-001-30fd`.

This change does not merge those pull requests. Telemetry is experimental. It is not Match Memory, not D1, and `distanceSaved` stays false.

| Check | Result | Evidence |
| --- | --- | --- |
| Kick-off does not wait for GPS, heart rate, storage, or signal | PASS in unit tests. Simulator resume of a running half advanced the clock in the same paint as GPS acquisition. | `telemetry.test.js` sensor-unavailable kick-off. Bip 6 log `FORREF_TEL gps=SEARCHING` after the clock was already `SECOND_HALF_RUNNING`. |
| Distance only in `FIRST_HALF_RUNNING` and `SECOND_HALF_RUNNING` | PASS | Unit test keeps first-half meters through half-time movement and adds the second half from a new anchor. |
| Half-time movement is zero | PASS | Same test. Delayed callback after the close does not change the closed half. |
| Second half starts from a fresh anchor | PASS | The jump from the first half is not added. The next accepted step is. |
| Match distance is the sum of the two halves | PASS | `distanceMeters` equals first plus second. |
| Pause, suspension, and `TIME_UNVERIFIED` add nothing and do not bridge | PASS | Unit test. Simulator restart of a running clock showed `TIME UNVERIFIED`, `0.00 km`, and `GPS OFF`. |
| GPS loss does not invent the missing segment | PASS | Invalid status and zero satellites drop the bridge. The next accepted step is only the new segment. |
| Live ↔ controls keeps one listener and the totals | PASS in unit tests. Simulator returned from Match Controls with the same running clock and `GPS OK`, without a second `gps=SEARCHING` line. | `pageExit` does not stop sensors. Live `onDestroy` does not release them. App `onDestroy` does. |
| Full time freezes totals and releases listeners | PASS | Unit test. |
| Locale distance | PASS | `150` m formats as `0.15 km` and `0,15 km`. Internal totals stay meters. |
| Clock regression | PASS | Existing `match_clock.test.js` plus a kick-off → full-time chain in `telemetry.test.js`. |
| Bip 6 build | PASS | `zeus build` and `zeus install` for Amazfit Bip 6, device sources `9765120`, `9765121`, `10158337`. Installed app id `29566`. Screen `390×450`. |
| Bip 6 simulator UI | PASS for presentation and phase gating. Distance accumulation on the simulator was not observed because the injected fix did not walk. | Screenshots under this folder's sibling artifacts. Compact line `0.00 km  HR ...  GPS OK` while running, `GPS OFF` while paused or unverified. |
| Corrected 4 m GNSS hold | PASS | Lab `analytics.test.js` and session-controller walking test still pass. Live uses `advanceDistance`. |
| Workout Extension, `getSportData`, native sport totals | Not used | Production permissions do not include `data:user.hd.workout`. Source scan rejects `getSportData`. |
| Heat map | PENDING | No route and no drawing. Page count stays 23. |
| 90-minute recording | NOT CERTIFIED | Not claimed. |
| Physical Bip 6 | NOT CERTIFIED | Simulator only. |

Sensor callbacks update memory and arm a 5 second totals flush. They do not read a journal and they do not write on the callback itself. A failed or oversized write increments `uncertified` and leaves the clock phase unchanged.
