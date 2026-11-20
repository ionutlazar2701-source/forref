# Test matrix — Native Familiarity V5

Watch `npm test`: geometry pass, 119 node tests pass, exit 0. `./tool/verify_cloud.sh`: match core 377, persistence 92, phone 126, exit 0.

`DISPLAY_CONTINUITY_MS` stays 2500. Live A/C hit rectangles stay on the 1.0.6 coordinates.

| Case | Result |
| --- | --- |
| Open the workspace | page 1, Live |
| Button or key from Controls or Cautions | page 1, no intent, abandon disarmed |
| Platform left slide | BLOCKED, not consumed, no page change |
| Platform right slide on Live | not consumed, system Back |
| Platform right slide on page 0 or 2 | consumed, return to Live, no intent |
| Pointer starts on HOME and moves | cancel, neither team selected |
| Pointer swipe in empty space | would change page and still emit no intent; not wired on device |
| Dots versus team, control, and stacked rows | no overlap on 390×450 or 480×480 |
| Score and cautions | unavailable labels only |

`createSysTimer` during screen-off is not part of this prototype. CLOCK-SLEEP remains a separate investigation.
