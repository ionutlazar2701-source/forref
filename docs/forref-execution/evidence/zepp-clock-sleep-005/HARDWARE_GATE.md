# Hardware gate — CLOCK-SLEEP-005

Status: **LOCAL GATE REQUIRED**.

1.0.7 on Amazfit Bip 6 continued after about 1 second of screen-off and became `TIME_UNVERIFIED` after about 3–4 seconds. No tick log was captured. 1.0.8 shows the witness line after wake so the next run can separate a missing callback, a callback that did not commit, and a checkpoint that did not recover.

Cloud tests inject the UTC values. They do not show that `createSysTimer` fired on this watch during the first five seconds. Certification waits until 3, 4, and 5 second screen-off steps pass the rule in `HARDWARE_PROTOCOL.md`.
