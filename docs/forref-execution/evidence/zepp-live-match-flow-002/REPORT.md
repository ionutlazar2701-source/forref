# FORREF ZEPP LIVE MATCH FLOW 002

Functional revision `a754ae451abf480c0a1045222b1eb2cddb756d25`. Boot line: `FORREF_LIVE002_BOOT build=live-match-flow-002 rev=a754ae451abf480c0a1045222b1eb2cddb756d25`.

## Fixes

Abandon confirmation is a latch. Navigation, Back, page exit, and a changed phase or mode clear it. The next tap arms again. It does not confirm.

Live calls `liveFrame` before it creates widgets. Running digits use the last admitted sample. A step longer than 2.5 seconds is an unsampled gap: the screen shows dashes, and a whistle does not add that gap to the half. A tick updates the text widgets only. The team buttons say HOME · NO SCORE and AWAY · NO SCORE.

A second-half unsampled gap reports the last known match clock, including the 45:00 offset. It does not report the raw second-half offset.

The prototype store for this build is `forref_clock001c_state`. `forref_clock001b_state` and the probe files were left in place. A page exit writes the last admitted sample. The log reason is `READBACK_ONLY_NOT_D1`.

True Black theme work is not in this PR. The route inventory is 23, including Match Controls. See `ROUTE_INVENTORY.md`.

## Simulator

| Item | Observed |
| --- | --- |
| Simulator | Zepp OS Simulator 2.1.2 |
| Zeus | 1.10.0, target Amazfit Active 3 Premium, sources 10944768, 10944769, 10944771, 10948867 |
| Guest | Amazfit Active Max, source 10813699, 480×480 round. QEMU pid 17708 stayed up across the recreate |
| When | 18:18–18:23 Europe/Bucharest, Thursday 12 Nov 2026. Console timestamps are UTC, two hours earlier |

Downloaded firmwares are Balance 2, Bip 6, Active 3 Premium, and Bip Max. This round session used Active Max. Bip 6 was launched later for T24. See `rectangular/T24_RECTANGULAR_REPORT.md`.

## What the guest did

| UTC | Result |
| --- | --- |
| 16:19:07 | Live A READY `00:00`, team buttons HOME · NO SCORE and AWAY · NO SCORE |
| 16:19:15 | Kick Off on Live A. `RDY>H1R` at `00:00`. The clock reached `00:04` RUNNING |
| 16:19:33 | Apps-list recreate while running. `PERSIST|READBACK_ONLY_NOT_D1`. QEMU pid unchanged |
| 16:19:47 | `LOAD|H1R>H1R|…|UNVERIFIED`. Screen: TIME UNVERIFIED, dashes, LAST KNOWN 00:16 |
| 16:20:15 | CONTINUE FROM LAST. `H1R>H1P` at `00:16`. CLOCK PAUSED, not a filled gap |
| 16:20:27 | After HOME and a wait, the first Live paint was `UNVERIFIED` at last known `00:18` |
| 16:20:42 | END 1ST HALF from the paused clock. `H1P>HT` at `00:18` |
| 16:20:43 | Start 2nd Half. `HT>H2R` at `45:00` |
| 16:20:47 | 2nd half pause on Live A at `45:03`, still `45:03` on the later frame, then resume |
| 16:21:38 | Same session on Live C. Pause at `45:28`, held, resume to `45:29` |
| 16:21:51 | SUSPEND GAME from the paused 2nd half. `H2P>H2S` at `45:30`. Label MATCH SUSPENDED |
| 16:22:10 | First ABANDON tap. `REJECT` and the phase stayed `H2S` at `45:30`. Button became CONFIRM ABANDON |
| 16:22:12 | Back. `ARM|disarm|back|was-armed`. Live stayed MATCH SUSPENDED |
| 16:22:14 | Controls reopened on ABANDON GAME, not CONFIRM ABANDON |
| 16:22:18 | Second confirm. `H2S>ABD` at `45:30`. Screen: ABANDONED · NOT FULL TIME. No Kick Off |
| 16:22:59 | Romanian Live: GAZDĂ · FĂRĂ SCOR, OASPETE · FĂRĂ SCOR, ABANDONAT · NU E SFÂRȘIT |

## T01–T26

| ID | Verdict | Evidence |
| --- | --- | --- |
| T01 | PASS | `shots/T01-live-a-ready-noscore.png` |
| T02 | PASS | Kick Off on Live A. `shots/T02-live-a-kick.png`, `shots/T02-live-a-running.png` |
| T03 | PASS | One kickoff in the console. A second kickoff is refused by the unit test |
| T04 | PASS | Earlier guest pause held `00:04`. This run's 2nd-half pause held `45:03` and `45:28` |
| T05 | PASS | Resume continued from the paused sample |
| T06 | PASS | HOME returned to the same session. The gap was not shown as precise time |
| T07 | PASS | `HOME · DEMO — NOT RECORDED`. Team buttons carry NO SCORE |
| T08 | PASS | Injected clock. This guest half ended at `00:18` |
| T09 | PASS | `H1P>HT` at `00:18` |
| T10 | PASS | Half-time stayed `00:18`. 2H started at `45:00` |
| T11 | PASS | Unit covers `47:15`. Guest 2H launch is `HT>H2R` at `45:00` |
| T12 | PASS | 2H pause and resume on A and on C. `shots/T12-second-a-held.png`, `shots/T12-second-c-resumed.png` |
| T13 | PASS | Injected clock for `90 + 03:24` |
| T14 | PASS | Earlier full-time hold. This run's abandon is a different terminal state |
| T15 | PASS | Earlier suspend-from-running at `00:49` |
| T16 | PASS | `H2P>H2S` at `45:30`. `shots/T16-suspended-c.png` |
| T17 | PASS | Back cleared CONFIRM ABANDON. The confirmed tap became ABANDONED, not full time |
| T18 | PASS | Guest `REJECT` left `H2S` at `45:30`. Duplicate and other illegal intents stay in the node tests |
| T19 | PASS | Fault-injection unit tests |
| T20 | PASS | Page exit persisted the session and the same process returned to it |
| T21 | PASS | `LOAD|H1R>H1R|…|UNVERIFIED`. `shots/T21-recovered.png`, `shots/T21-continued.png` |
| T22 | PASS | Earlier frozen full-time restore. This generation starts from the new `001c` key |
| T23 | PASS | Corrupt and divergent copies fail closed in unit tests |
| T24 | PASS | Bip 6 guest, `getDeviceInfo()` `390×450` `shape=RECT` `screenShape=0` `deviceSource=10158337` `deviceName=Bip 6`. R01–R12 in `rectangular/T24_RECTANGULAR_REPORT.md` |
| T25 | PASS | `shots/T25-live-ro.png`, `shots/T25-settings-ro.png` |
| T26 | PASS | `npm test` exit 0, 29 tests, including the round and 390×450 geometry checks. `./tool/verify_cloud.sh` exit 0: Match Core 377, persistence 92, phone 125 |

26 PASS, 0 PARTIAL, 0 FAIL. T24 is the rectangular Bip 6 run. T01–T23 and T25 stay the earlier round-guest results.

## Limits

Official match time is not certified. Local D1 is not certified. Hardware, power loss, and battery are not certified. UNDO FULL TIME remains a human gate. The round-session guest is Active Max. The T24 guest is Bip 6. Accent colors are unchanged.

## Next single blocker

True Black recolor still waits on Founder review of a color candidate. This PR does not start that recolor.
