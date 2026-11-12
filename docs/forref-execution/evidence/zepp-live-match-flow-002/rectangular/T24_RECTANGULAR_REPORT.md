# T24 rectangular simulator

Guest identity comes from `getDeviceInfo()`, logged as `FORREF_DEVICE`. The Zeus target name and the simulator dropdown are recorded beside it. They are not the proof.

| Item | Observed |
| --- | --- |
| Simulator | Zepp OS Simulator 2.1.2 |
| Zeus | 1.10.0, `zeus dev -t "Amazfit Bip 6"`, sources 9765120, 9765121, 10158337 |
| Downloaded | Balance 2 v1.1.0, Bip 6 v1.1.0, Active 3 Premium v1.0.0, Bip Max v1.0.0 |
| Selected dropdown | Bip 6 v1.1.0 |
| Firmware | `bip6_os50_v110.zip`, cache `4ae8ec66a7e2d342faf040652f4f41ff` |
| QEMU | pid 36954, norflash from that cache. The previous Active Max process was replaced by the simulator |
| Window | 390×477, including the simulator chrome |
| `getDeviceInfo()` | `width=390 height=450 shape=RECT screenShape=0 deviceSource=10158337 deviceName=Bip 6 keyNumber=2 keyType=normal_20` |
| Boot line on this guest | `FORREF_LIVE002_BOOT build=live-match-flow-002 rev=a754ae451abf480c0a1045222b1eb2cddb756d25` |
| When | 22:55–23:05 Europe/Bucharest, Thursday 12 Nov 2026. Console timestamps are UTC, two hours earlier |

`shape=RECT` and `screenShape=0` are the guest values. On the earlier Active Max guest the same log used `shape=ROUND` and `screenShape=1`. The home screen paints `390×450 RECT src 10158337`. The framebuffer is a tall rectangle. The app does not paint a circular mask. `statusBar=64` in the log is the app layout constant, not an OS measurement. The OS title `FORREF` sits above the app content. No app control is under that title, so no geometry change was made.

The raw guest log is `console-bip6.txt`. It starts at the first Bip 6 `FORREF_DEVICE` line. Older Active Max lines stay in the simulator console and are not in this file.

## Presenter fix

The first second-half gap painted `LAST KNOWN 00:17` while the match clock had been `45:17`. The main digits were already dashes. `00:17` was the second-half offset, shown as if it were the match clock. `present()` now formats that last-known line with the same 45:00 offset as the running clock. Stored samples are unchanged. The retest painted `ULTIMUL CUNOSCUT 45:19`, and Continue From Last paused at `45:19`.

## R01–R12

Touches are real clicks on the Bip 6 window. Times below are the console UTC stamps.

| ID | Verdict | What the guest showed |
| --- | --- | --- |
| R01 | PASS | Live A, `1ST HALF · READY`, `00:00`. HOME and AWAY side by side, each `NO SCORE`. Kick Off and Match Controls visible. `shots/r01-live-a-ready.png`. `RDY>H1R` at `20:57:47` |
| R02 | PASS | Stayed on Live A. `00:01` then `00:04` RUNNING. `shots/r02-kick.png`, `shots/r02-running.png` |
| R03 | PASS | Pause held `00:05` across a 10s wait. Resume continued to `00:07`. `shots/r03-paused.png`, `shots/r03-held.png`, `shots/r03-resumed.png` |
| R04 | PASS | Paused at `00:21`. HOME opened Yellow / Red / Goal / Sub. Yellow opened the participant list and did not say Saved. Back returned to the same paused session. `shots/r04-event.png`, `shots/r04-player.png`, `shots/r04-live-return.png` |
| R05 | PASS | Display switched to C. HOME on top, clock in the middle, AWAY below, still paused `00:21`. `shots/r05-live-c.png` |
| R06 | PASS | On C, resume ran `00:22` to `00:26`. Pause held `00:26`. The two controls do not overlap. `shots/r06-c-running.png`, `shots/r06-c-held.png` |
| R07 | PASS | Match Controls on the rectangle shows End 1st Half, Suspend Game, Display, and Back To Live, each fully visible. End 1st Half was then used. `shots/r07-controls-1h.png` |
| R08 | PASS | `H1P>HT` at `00:26` (`20:59:32`). `HT>H2R` at `45:00` (`20:59:34`). Still running at `45:05`, so 45:00 did not end the half. Explicit `H2P>FT` at `45:22` (`21:05:13`) and the next frame stayed `45:22`. `shots/r08-halftime.png`, `shots/r08-2h-start.png`, `shots/r08-2h-still-running.png`, `shots/r08-full-time.png`, `shots/r08-full-time-held.png`. The guest was not left running until 90:00. The 90:00 boundary stays in the node test |
| R09 | PASS | `H2P>H2S` at `45:06` and again at `45:19`. First Abandon tap logged `REJECT` and stayed suspended. Back logged `ARM\|disarm\|back\|was-armed`. Reopen showed Abandon Game, not Confirm. Resume Game is the formal return and lands in `SECOND_HALF_RUNNING` (`H2S>H2R`). `shots/r09-confirm.png`, `shots/r09-reopen.png`, `shots/r09b-confirm-ro.png`, `shots/r09b-reopen-ro.png` |
| R10 | PASS | A running second half left on Match Controls past 2.5s returned `UNVERIFIED` (`21:01:51`, and again `21:04:24` after the fix). The main clock is dashes. After the fix the detail line is the match clock `45:19`, and Continue From Last pauses there. `shots/r10-unverified.png` is the pre-fix `00:17` line. `shots/r10b-unverified-ro.png` and `shots/r10b-continued-ro.png` are the retest |
| R11 | PASS | English: Match Controls, Start 2nd Half, Time Unverified, Confirm Abandon. Romanian: Setări, Comenzi Meci, Timp Neverificat, Confirmă Abandon, Timpul Regulamentar, Continuă de la ultimul, Gazdă · Fără scor. `ÎNCEPE REPRIZA 2` was not on screen after the second half had started. Continuă de la ultimul is longer and fits the same half-width control. `shots/r11-settings-ro.png`, `shots/r11-controls-ro.png`, `shots/r08-halftime.png`, `shots/r09b-confirm-ro.png` |
| R12 | PASS | A at `45:06`, then C at `45:06`, then A at `45:06`. Phase stayed 2nd half paused. `shots/r12-live-a.png`, `shots/r12-live-c.png`, `shots/r12-live-a-again.png` |

Recording of the half-time to second-half controls: `r08-half-to-second.mp4` (32s). Shell with the Bip 6 dropdown and the rectangular full-time screen: `shots/device-manager-bip6.png`.

## Verdict

T24 PASS. Exact 390×450 PASS. R01–R12 PASS.

`npm test` in `apps/forref_watch_zepp` exited 0: geometry, 4 abandon-arm tests, live surface, and 29 node tests in total. The geometry run still prints the round 480 layouts and the 390×450 layouts. The round guest was not relaunched. This change does not move controls.

`./tool/verify_cloud.sh` exited 0. Match Core 377, persistence 92, phone 125.

Official match time, local D1, hardware, power loss, and battery are not certified. True Black is not in this PR. Match Core, D1, and temporal-authority contracts are unchanged.
