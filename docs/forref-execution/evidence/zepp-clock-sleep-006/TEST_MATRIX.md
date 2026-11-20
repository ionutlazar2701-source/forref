# Test matrix — clock sleep 006

Watch `npm test` and `./tool/verify_cloud.sh` counts are filled after those commands finish.

`DISPLAY_CONTINUITY_MS` stays 2500.

| Case | Cloud result |
| --- | --- |
| 1.0.8 shape: start `ok`, no callback, checkpoint age 20653, admit `HELD` | `L=SERVICE` |
| `UNSAMPLED_GAP` followed by `HELD` | `r` stays `UNSAMPLED_GAP` |
| Two callbacks before a screen value, second delta 4000 | `n=2`, `x=4000`, screen still empty, checkpoint unset |
| Failed write, then write without readback, then readback | `WRITE`, then `READ`, then `w=3/2/1` |
| Init stored and no callback | `L=TIMER` |
| Callback spacing 5000 with no checkpoint | `L=GAP`, closed time unchanged |
| 1 s and 2 s with no background tick | admitted, `00:01` and `00:02` |
| 3 s, 4 s, and 5 s with no background tick | `UNSAMPLED_GAP`, digits null |

`createSysTimer` during a physical 5-second screen-off is not in this matrix. See `HARDWARE_GATE.md`.
