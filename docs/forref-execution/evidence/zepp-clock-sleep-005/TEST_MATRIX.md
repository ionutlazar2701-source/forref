# Test matrix — clock sleep 005

Watch `npm test` and `./tool/verify_cloud.sh` counts are filled after those commands finish.

`DISPLAY_CONTINUITY_MS` stays 2500.

| Case | Cloud result |
| --- | --- |
| 1 s and 2 s with no background tick | admitted, `00:01` and `00:02` |
| 3 s, 4 s, and 5 s with no background tick | `UNSAMPLED_GAP`, closed milliseconds unchanged, digits null |
| Five off-screen ticks, one per second, file and mirror read back | `off=5`, `max=1000`, wake `CONTINUITY_RESUMED` |
| Service tick with `screen=on` | no witness write, `off` stays 0 |
| Off callback at 4 s, class `TIMER_GAP` | `off=1`, `max=4000`, `ck=none`, closed time unchanged |
| Corrupt witness bytes | empty witness, no checkpoint |
| Protocol text | intervals 1, 2, 3, 4, and 5; no `pair=match` required while the screen is on |

`createSysTimer` during physical screen-off is not in this matrix. See `HARDWARE_GATE.md`.
