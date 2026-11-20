# Test matrix — clock sleep 002

Watch `npm test` on 20 Nov 2026: geometry pass, 102 node tests pass. `./tool/verify_cloud.sh`: match core 377, persistence 92, phone 126, exit 0.

The new host tests drive `createServiceHost` with a mock whose `queryPermission` returns `Array<number>` and does not call a callback. That mock leaves the 1.0.4 callback loop pending and never calls `start`.

| Case | Cloud result |
| --- | --- |
| Synchronous `queryPermission` returns `[2]` | `start` once, `reload: false`, `file` set, `requestPending` false |
| Query returns `[0]`, request returns `0`, callback later `[2]` | `start` only after the callback |
| Request returns `2` | start immediately |
| Request returns `1`, or query returns `[1]` | no start, pending false, no retry loop |
| `queryPermission` throws, then a later query returns `[2]` | first call does not stick pending; second call starts |
| `stop` throws, or callback `result` false | `running` stays true; arguments include `file` and `complete_func` |
| `stop` returns `0` | `running` becomes false |
| Service already listed | no second `start` |
| Screen status `1` / `2` | `on` / `off` |
| Verified pause and half-time | frozen elapsed, no service required |
| Pause or half-time after a 30 s unsampled gap | `UNVERIFIED`, closed time unchanged |
| Running memory versus a stored pause or half-time | stored hold kept, service tick stops, no write |
| 5 / 30 / 120 s observation chain, and one paint with no chain | unchanged from 001; window stays 2500 ms |

`createSysTimer` during physical screen-off is not in this matrix. See `HARDWARE_GATE.md`.
