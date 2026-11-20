# Test matrix — clock sleep 004

Watch `npm test`: geometry pass, 121 node tests pass. `./tool/verify_cloud.sh`: match core 377, persistence 92, phone 126, exit 0.

`DISPLAY_CONTINUITY_MS` stays 2500.

| Case | Cloud result |
| --- | --- |
| 5, 30, and 120 one-second service ticks, file and mirror read back | exact `00:05`, `00:30`, `02:00`; class `CHAIN`; wake `CONTINUITY_RESUMED` |
| One callback at 5, 30, or 120 seconds | `TIMER_GAP`, `UNSAMPLED_GAP`, closed milliseconds unchanged, digits null |
| Mirror write throws | class `PERSIST`, stored session null, elapsed not taken from that tick |
| No `service=on` / timer not created / no off ticks | `SERVICE` / `TIMER_CREATE` / `TIMER_SILENT` |
| Chain ticks, then wake `RECOVERY_REQUIRED`, `UNSAMPLED_GAP`, or `CONFLICT` | `RECOVERY` |
| Same UTC twice | second tick `HELD`, no write |
| Pause after a running start | `stop-reason=phase` |
| Unverified session after a running start | `stop-reason=unverified` |
| `start` code 0 / 3 / 7 | `ok` / `permission` / `limit` |
| Foreground binder | still `createTimer` and `sampleFromScheduler` |

`createSysTimer` during physical screen-off is not in this matrix. See `HARDWARE_GATE.md`.
