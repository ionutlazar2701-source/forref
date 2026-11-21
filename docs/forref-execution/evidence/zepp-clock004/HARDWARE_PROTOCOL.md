# CLOCK-004 — physical Bip 6 validation protocol

State: **NOT TESTED**. Fill every result from a physical Amazfit Bip 6 and an independent stopwatch. Do not use this watch as the reference clock.

Production FORREF is app id `29566`. This trial installs app id `30104` only. Do not change `DISPLAY_CONTINUITY_MS` (`2500`) from anything observed here. A recovered display is `UTC_ASSUMED`. It is not `PROVEN_TIME`.

## Install

1. Scan `CHRON004_PREVIEW_QR.png` with the Zepp app on the phone paired to the Bip 6. Developer mode must be on.
2. Package `30104-CHRON-004-1.0.0-20261121111810.zab`, 16084 bytes, sha256 `4270480f665e43c1ff4544c25d99a06e606cff659a0c9c8d5486b9dcb1050f10`.
3. The preview QR expires 28 Nov 2026, 13:18:13 Europe/Bucharest (11:18:13 UTC).
4. Open `CHRON-004`. The title sits under the status bar. The first screen offers `START` / `START` and the detail line says this is not a match.
5. Record firmware, device source (`9765120`, `9765121`, or `10158337`), battery at the start and end, and whether phone time sync is on.
6. If the developer bridge is connected, keep the `CHRON004` log. `ticks=` is the cosmetic one-second callback count. The digits come from the stored UTC anchor.

`TIME UNKNOWN` means the record was rejected or a live phone-time callback fired. `UTC_ASSUMED` means the anchor math ran and nothing proved the civil clock was continuous.

## Trial matrix

| Test | Steps | Capture | Result |
| --- | --- | --- | --- |
| S30 | `START` together with the reference stopwatch. Screen off 30 s, then wake. | Display near `00:30`. Record `ticks`, whether the app was killed, and whether relaunch restored this page. Trust label must be `UTC_ASSUMED`. | NOT TESTED |
| S120 | Screen off 120 s. | Display against the reference, ±1 s. Same relaunch notes. | NOT TESTED |
| S600 | Screen off 600 s. | Display against the reference, ±1 s. This is the match-relevant gap. | NOT TESTED |
| REOPEN | `START`, leave the app, reopen after 2 min. | Same anchor. The clock must not restart at `00:00`. Log `seq` must not go backwards. | NOT TESTED |
| PAUSE | Run 1 min, `PAUSE` 30 s, `RESUME` 1 min. | Display excludes the paused 30 s. | NOT TESTED |
| HALF | Pause, `END H1`, wait 2 min, `HALF 2`. | The wait is excluded. Second-half kickoff shows `45:00`. | NOT TESTED |
| STEP-ACTIVE | While `RUNNING` and the UI is alive, change the phone or watch clock by +120 s. | Expect `TIME UNKNOWN` and reason `PHONE_TIME_SETTING` if the callback fires. If the digits jump and stay `UTC_ASSUMED`, record that as a failure of the live listener. | NOT TESTED |
| STEP-SLEEP | Change the source clock by +120 s while the screen is off and the app is not running. | Record whether the wake display follows the stepped clock while still saying `UTC_ASSUMED`. That result must not be called `PROVEN_TIME`. | NOT TESTED |
| DISCONNECT | Disable phone Bluetooth for 2 min during a running segment. | No phone path is required for the subtraction. Compare the reference. | NOT TESTED |
| BATTERY | Separate 2-hour screen-on pass, not part of the sleep matrix. | Start and end battery, and whether the screen stayed lit. | NOT TESTED |

A row within 1 s of the reference is a functionality observation. It does not authorize replacing the 2,500 ms continuity guard. An undetected civil-time step during sleep stays an open temporal-authority question.

If both slots are torn, the screen stays `TIME UNKNOWN` / `NO_RECORD` and will not start a fresh anchor. Uninstall `CHRON-004` to clear its `/data` files before a new trial.
