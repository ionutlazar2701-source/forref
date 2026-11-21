# Test matrix — clock sleep 007

Watch `npm test`: geometry pass, 145 node tests pass. `./tool/verify_cloud.sh`: match core 377, persistence 92, phone 126, exit 0.

`DISPLAY_CONTINUITY_MS` stays 2500.

| Case | Cloud result |
| --- | --- |
| 1.0.9 shape: init stored, no callback, no timer field | `UNRECORDED`, line `T=-` |
| Timer create failed | `NOT_CREATED`, `T=fail` |
| Timer id stored, destroy stored, no callback | `DESTROYED_BEFORE_CALLBACK` |
| Timer id stored, service still listed, no callback | `NOT_DELIVERED` |
| 5000 ms experiment counted, match callback absent | `LONG_PERIOD_ONLY` |
| Service absent on wake | `SERVICE_ABSENT` |
| First match callback stored | `CALLBACK_RECORDED` |
| Painted line | at most 48 characters, the gap reason is not painted |

A physical `createSysTimer` id is not in this matrix. See `HARDWARE_GATE.md`.
