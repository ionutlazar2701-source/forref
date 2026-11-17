# Limitations and next decision

Decision: **`HARDWARE_EVIDENCE_PENDING`**

The single remaining hardware blocker is physical Bip 6 screen-off GNSS continuity. App Service cannot run Geolocation, and the Workout Extension device list does not include Bip 6. The Founder runs stage A in `BIP6_HARDWARE_TEST_PROTOCOL.md`. Until that note exists, the lab must not be described as a continuous match GPS recorder.

## Acceptance

| Id | Verdict | Why |
| --- | --- | --- |
| SENS01 | PASS | Isolated app id 30101, namespace `forref_sens_001`, own permissions, guest launch on Bip 6. Production app id 29566 and its 23 routes are unchanged. |
| SENS02 | PARTIAL | Real `Geolocation` is wired, including permission denial and status `V` in tests. The guest returned simulator status `A`. No hardware fix was observed. |
| SENS03 | PARTIAL | Real `onCurrentChange` / `offCurrentChange` and teardown are tested with a fake sensor. The guest showed `HR UNAVAILABLE`. No hardware pulse was observed. |
| SENS04 | PARTIAL | Distance is stored as a raw number with unit and attribution `UNRESOLVED`, and it is excluded from GNSS distance. Hardware unit and session scope are unresolved. |
| SENS05 | PASS | Journal tests: empty missing file, torn tail refuses append, capacity, short write, explicit delete, session ids `LAB-0001` then `LAB-0002` without rewrite. A 90-minute 1 Hz GNSS+HR session needs 10,800 entries and 4,989,648 bytes. The byte cap stops it at 1,134 pairs. `enduranceReady` is false. |
| SENS06 | PARTIAL | Gap quantification is tested, including `SCREEN_OFF_OR_PAUSE`, `STALL`, and `RESTART_UNMEASURED` with a null duration. Screen-off GNSS survival on the guest and on hardware was not measured. That observation is **BLOCKED**. No continuity was invented. |
| SENS07 | PASS | Deterministic distance and speed tests passed, including stationary drift, teleport, spike rejection, a 10-minute gapped trace, and a refusal to mix two session ids. |
| SENS08 | PARTIAL | Synthetic heat-map tests passed. The device heat page uses the latest session only and shows `HEAT MAP UNAVAILABLE` or `NO FIELD CALIBRATION`. It does not draw a map. |
| SENS09 | PASS | Foreground Device App is the only GNSS path. App Service is heart-rate only. Workout Extension is not shipped because Bip 6 is absent from the published device list. |
| SENS10 | PASS | Bip 6 guest ran. Identity `10158337`, 390×450. Logs and redacted screenshots are in `guest/`. Simulator status `A` is labeled synthetic. |
| SENS11 | PARTIAL | `zeus preview -t "Amazfit Bip 6"` opened a login page and printed no install QR. `zeus status` remains `no login`. **PHYSICAL_INSTALL_PENDING.** |
| SENS12 | PASS | `./tool/verify_cloud.sh` exit 0: Match Core 377, persistence 92, phone 126. Sensor-lab `npm test`: 18 passed, 0 failed. No Match Core, clock, or production-route edits. Privacy limits are above. |

## Privacy limits

Raw coordinates and pulse stay on the device. Console text and this folder do not contain them. The status image has the simulator coordinate row covered. Delete local data after a hardware session. Do not commit `*.journal` or `dist/`.

## What this does not change

Phone Match Memory remains the only match writer. There is no `Saved`, no official score, and no official minute. PR #48 stays unmerged and unmodified.
