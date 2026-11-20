# NF01–NF08 — Native Familiarity V5

Source baseline: `235f789fb218730e6a6efafc809a2215df7a4e30`. Prototype functional rev: `75f6757b361962290156ff2f415994c223a52617`. Profiles: 390×450 rectangular and 480×480 round. Layout renders only. Hardware is not certified.

| Gate | Status | Evidence |
| --- | --- | --- |
| NF01 CROSS-SHAPE | PARTIAL | Both profiles place Live, Controls, and Cautions inside the safe area in tests. Dots do not intersect team or control rectangles. Frames: `frames/rect-*.png`, `frames/round-*.png`. Not a device framebuffer. |
| NF02 TIMER FIRST | PARTIAL | Phase stays above the clock on Live A. Unverified time uses the warning color and does not show running digits. `DISPLAY_CONTINUITY_MS` stays 2500. The foreground sampler is unchanged. The 2:1 ratio against a visible OS clock was not measured; this app does not draw the OS clock. |
| NF03 TELEMETRY MID | PARTIAL | The existing one-line telemetry slot remains under the clock. Unavailable distance, heart rate, and GPS use the current labels. No sample heart rate was added. Sensor ownership was not changed. |
| NF04 TEAM ENTRY | PARTIAL | HOME and AWAY keep the 1.0.6 hit rectangles. The separator sits in the gap between them. A pointer that starts on a team button and moves does not select a team. Abbreviations and kit colors are absent, so the labels stay `NO SCORE`. |
| NF05 CAROUSEL | PARTIAL | Pages are 0 Controls, 1 Live, 2 Cautions. Live is the default. Dots follow the index. Buttons move pages and emit no intent. Forward swipe is BLOCKED. Right-slide Back returns to Live from pages 0 and 2 and stays system Back on Live. LOCAL HARDWARE GATE. |
| NF06 DISCIPLINE | BLOCKED | The cautions page shows the open G1 ledger state. No entries are invented. DOMAIN GATE remains OPEN. |
| NF07 REGRESSION | PARTIAL | 23 routes remain. Live A and C hit rectangles are unchanged. Cloud tests cover the clock and the phone. The physical Goal, Card, Substitution, Controls, and reopen check from 1.0.6 was not re-run on this package. |
| NF08 DEVICE UX | BLOCKED | Wrist, sweat, sunlight, accidental swipe, and return-to-Live latency require the watch. LOCAL HARDWARE GATE. |

Founder decision requested: ACCEPT / REVISE / REJECT. No merge.
