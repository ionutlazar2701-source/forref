# FORREF ZEPP LIVE MATCH FLOW 002

Branch: `cursor/zepp-live-match-flow-002-30fd`. Functional commit: `6fbb3829e8054f9bf9215ffe6ce8602a421f60dc`. This file records the simulator retry after the watch emulator was available.

## What the build does

Live Match uses `layoutLive` for A (HOME and AWAY side by side) and C (HOME, clock, AWAY). Both are one `match_clock` session. Kick Off, Pause, Resume, Start 2nd Half, and Resume Game stay on Live. Match Controls holds End 1st Half, Suspend Game, Full Time, and a two-step Abandon. Score stays SCORE UNAVAILABLE. The event page says DEMO — NOT RECORDED.

No Match Core, persistence, or phone files were edited. Readback is not D1. `Time.getTime()` is an unverified wall clock. `createTimer` only refreshes the display.

## Simulator

| Item | Observed |
| --- | --- |
| Simulator | Zepp OS Simulator 2.1.2, `--no-sandbox`, `DISPLAY=:1` |
| Zeus | 1.10.0, `zeus dev -t "Amazfit Active 3 Premium"` |
| Zeus device sources | 10944768, 10944769, 10944771, 10948867 |
| Guest actually running | Amazfit Active Max, `deviceSource=10813699`, 480×480 ROUND, QEMU pid 17708, norflash `a2d75bdaa82cc958b916eab4bf0192ba` |
| Boot marker | `FORREF_LIVE002_BOOT build=live-match-flow-002!` |
| KVM | not changed. This user is not in group 103 |

Console timestamps below are UTC. Europe/Bucharest is two hours ahead.

## What was clicked

One session, then a process recreate that kept the same QEMU pid.

| UTC | Result |
| --- | --- |
| 15:56:17 | Live A READY `00:00`, then Live C READY `00:00` |
| 15:57:39 | Kick Off on Live C. `RDY>H1R` at `00:00`. Screen reached `00:03` RUNNING |
| 15:57:44 | Pause. `H1R>H1P` at `00:04`. Still `00:04` after 15 seconds. Label CLOCK PAUSED |
| 15:58:02 | Resume. `H1P>H1R` at `00:04`. Screen then showed `00:06` RUNNING |
| 15:58:15 | HOME opened. Title `HOME · DEMO — NOT RECORDED`. No score change |
| 15:58:30 | Back to Live C, still RUNNING, now `00:34` (the gap counted as play) |
| 15:58:47 | Suspend Game. `H1R>H1S` at `00:49`. Live C and Live A both showed MATCH SUSPENDED `00:49` |
| 15:59:30 | Resume Game. `H1S>H1R` at `00:49`. The suspended gap was not added |
| 15:59:35 | Half-time on Live A, frozen `00:54` |
| 15:59:48 | Start 2nd Half. `HT>H2R` at `45:00`. Live A showed `45:01` |
| 16:00:29 | Same session on Live C, `2ND HALF · RUNNING` `45:41` |
| 16:00:41 | Full Time. `H2R>FT` at `45:53`. Held on a later frame. Reopen stayed `45:53` |
| 16:02:08 | Apps-list recreate. New epoch `e1794499328915`. QEMU pid still 17708 |
| 16:02:22 | `LOAD|FT>FT|45:53|FROZEN_OBSERVED` on Live A |

Abandon was not pressed on the guest. A running-clock recreate was not performed; the recreate happened at full time. No rectangular guest was launched. The UI language was English (`en-US`).

The first long recording failed because the window height 507 is odd and the encoder rejected it. `zepp-live-full-time.mp4` is 12 seconds of the frozen full-time screen and the Back click.

## Node and cloud tests

Unchanged from the functional commit: `npm test` exit 0 (geometry pass, 19/19). `./tool/verify_cloud.sh` exit 0 (Match Core 377, persistence 92, phone 125, analyze clean).

## T01–T26

| ID | Verdict | Evidence |
| --- | --- | --- |
| T01 | PASS | `shots/T01-live-a-ready.png`, `shots/T01-live-c-ready.png`, both `00:00` |
| T02 | PASS | Kick Off stayed on Live C and the clock advanced. `shots/T02-live-c-kick.png` |
| T03 | PASS | Unit test. One kickoff in the console |
| T04 | PASS | `00:04` held through `shots/T02-live-c-paused.png` |
| T05 | PASS | Resume from `00:04` to `00:06`. `shots/T02-live-c-resumed.png` |
| T06 | PASS | `shots/T05-nav-return.png` still RUNNING after HOME |
| T07 | PASS | `shots/T05-team-home.png` and SCORE UNAVAILABLE on every live shot |
| T08 | PASS | Injected clock. The guest half ended at `00:54`, before 45:00 |
| T09 | PASS | `shots/T03-half-time-a.png` and `VIEW\|A\|HALF_TIME\|00:54` |
| T10 | PASS | Half-time stayed `00:54`; 2H started at `45:00` |
| T11 | PASS | Unit covers 1H `47:15`. Guest 2H launch is `HT>H2R` at `45:00` |
| T12 | PARTIAL | 2H ran on A and C. Pause/Resume was exercised in the first half, not the second |
| T13 | PASS | Injected clock for `90 + 03:24` |
| T14 | PASS | `shots/T03-full-time-c.png` and `shots/T03-full-time-held.png`. No Kick Off |
| T15 | PASS | `H1R>H1S` at `00:49`, `H1S>H1R` at `00:49`. `shots/T04-suspended-c.png` |
| T16 | PARTIAL | Suspend-from-paused is a unit test. The guest suspend started from RUNNING |
| T17 | PARTIAL | Confirmed abandon is a unit test. It was not pressed on the guest |
| T18 | PARTIAL | Illegal and duplicate intents are unit-tested. The guest log shows accepted transitions |
| T19 | PASS | Fault-injection unit tests |
| T20 | PASS | Back left Live and Open Live returned `45:53` in the same process |
| T21 | PARTIAL | Running recreate is a unit test. The guest recreate was at full time |
| T22 | PASS | `LOAD\|FT>FT\|45:53\|FROZEN_OBSERVED`. `shots/T22-restored-full-time.png` |
| T23 | PASS | Corrupt and divergent copies fail closed in unit tests |
| T24 | PARTIAL | Round A and C were on the guest and inside the safe area (`fit=1`). Rectangular layout is the geometry test only |
| T25 | PARTIAL | English labels on the guest. Romanian keys exist and were not switched on the device. No `67:12` or `1-0` |
| T26 | PASS | Watch tests and `./tool/verify_cloud.sh` exit 0 |

19 PASS, 7 PARTIAL, 0 FAIL, 0 BLOCKED, 0 NOT RUN.

## Limits

Official match time is not certified. Local D1 is not certified. Hardware, power loss, and battery are not certified. UNDO FULL TIME remains a human gate. The guest is Active Max even though Zeus was pointed at Active 3 Premium.

TRUE BLACK THEME 001 is not started. These screenshots are the pre-theme baseline. Accent colors still need Founder review before any native recolor.

## Next single blocker

Founder review of a true-black color candidate before any native recolor. On the watch, the open device gaps are a second-half pause, a confirmed abandon, a running-clock recreate, a rectangular guest, and a Romanian pass.
