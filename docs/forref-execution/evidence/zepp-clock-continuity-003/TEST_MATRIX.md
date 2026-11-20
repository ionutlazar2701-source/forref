# Test matrix — clock continuity 003

Watch `npm test` after the functional commit: geometry pass, 113 node tests pass. `./tool/verify_cloud.sh`: match core 377, persistence 92, phone 126, exit 0.

`DISPLAY_CONTINUITY_MS` remains 2500 in the navigation, continuity, and host suites.

| Case | Cloud result |
| --- | --- |
| 12 s on Event, then 12 s on Player, then 12 s on Review, one observation per second | exact `00:36`, trust not unverified, file = key = mirror |
| 12 s, and also 5 / 30 / 120 s, with no observer | `UNSAMPLED_GAP`, closed milliseconds unchanged, digits null |
| Service ticks for 5, 30, and 120 s while `writeKv` returns false | exact `00:05`, `00:30`, `02:00`; readback `FILE_MIRROR`; next load inside 2500 ms is `CONTINUITY_RESUMED` |
| Same 5 / 30 / 120 s with the mirror checkpoint and no tick | `RECOVERY_REQUIRED`, closed milliseconds stay 0, digits null |
| File and LocalStorage differ, and there is no mirror reader | `CONFLICT`, stored session null |
| File equals mirror, LocalStorage is a different session | file session accepted |
| Pause after 10 s, then a 12 s step | frozen at the whistle (`00:11`), reason `HELD` |
| Same UTC sampled twice | second tick `HELD`, no write |
| Empty service list twice after a start | second empty list does not start; the third sync starts again with `reload: false` |
| `getAllAppServices` throws | no extra `start` |
| Event, Player, Review sources | no `createTimer` |
| `app.js` | `startForegroundClock` / `stopForegroundClock` |
| Service source | `clock_service_store` and `createSysTimer`; no `clock_device`, no `@zos/storage` |

These tests drive the admission function with injected UTC. They do not measure Bip 6 sleep.
