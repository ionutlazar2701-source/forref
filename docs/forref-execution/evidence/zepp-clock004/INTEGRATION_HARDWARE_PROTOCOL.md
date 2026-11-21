# CLOCK-004 integrated FORREF — Bip 6 protocol

State: **NOT TESTED**. Every row below is for a physical Amazfit Bip 6 and an independent stopwatch. Cloud tests and a Zeus compile do not fill a row.

This package is production FORREF, app id `29566`, version `1.0.11` (code 11). It is not the CHRON-004 probe (`30104`). Founder observations on that probe (90-minute continuity, sleep, relaunch, Bluetooth off, pause/resume, second half at `45:00`, about 2 percentage points of battery) are the reason this integration was approved. They are not results for this build, and they are not certification.

## Install

1. Scan `CLOCK004_INTEGRATION_QR.png` with the Zepp app on the phone paired to the Bip 6. Developer mode must be on.
2. Package `29566-FORREF-1.0.11-20261121123241.zab`, 302410 bytes, sha256 `7f9d61f9e50cc976afc5437b3023935b751ff749dce4fda9243be2923881ffd0`.
3. Preview URL `zpkd1://api-mifit-de2.zepp.com/custom/tools/app-dial/download/KSPFsmJAHFoJdgIYxmSHqBsnCiJcJQzG`.
4. The preview QR expires 28 Nov 2026, 14:32:44 Europe/Bucharest (12:32:44 UTC).
5. Zeus compiled device sources `9765120`, `9765121`, `10158337` (QJSC, 25 files). That is a package build, not a match.
6. Open FORREF, reach Live, and kick off. Record firmware, device source, battery at start and end, and whether phone time sync is on.
7. The screen does not need to stay lit. Bluetooth is not required for the subtraction.

A healthy running display is `UTC_ASSUMED`. It is not `PROVEN_TIME`. Hidden digits mean `TIME_UNKNOWN` / `TIME_UNVERIFIED`.

## Trial matrix

| Test | Steps | Capture | Result |
| --- | --- | --- | --- |
| TICK | Kick off with the reference. Leave the screen on for 60 s. | Digits near `01:00`, ±1 s. | NOT TESTED |
| S30 | Screen off 30 s, then wake. | Display near the reference. App may have been killed. Relaunch must restore the same match. | NOT TESTED |
| S120 | Screen off 2 min. | Display against the reference, ±1 s. | NOT TESTED |
| S600 | Screen off 10 min. | Display against the reference, ±1 s. | NOT TESTED |
| H1 | Run to about 45:00. Do not expect the half to end by itself. | `45:00`, then added time as `45 + mm:ss` if left running. | NOT TESTED |
| HALF | End first half. Wait 2 min at half-time. Start second half. | The wait is excluded. Second-half kickoff shows `45:00`. | NOT TESTED |
| H2 | Run the second half to about 90:00. | `90:00`, then `90 + mm:ss` if left running. Full time is a separate action. | NOT TESTED |
| M90 | One continuous 90 min from kick-off through second-half start, including at least one sleep longer than 2 min. | Final display against the reference before full time. | NOT TESTED |
| PAUSE | Run 1 min, pause 2 min, resume 1 min. | The paused 2 min are excluded. | NOT TESTED |
| SUSPEND | Suspend, wait 2 min, resume the match. | The suspension is excluded. | NOT TESTED |
| NAV | From Live, open Goal, Card, Substitution, and Match Controls, then return. Repeat across a 1 min gap. | The clock continues. It does not restart at `00:00`. | NOT TESTED |
| REOPEN | Leave the app and reopen after 2 min. | Same match, same anchor. | NOT TESTED |
| BT | Disable phone Bluetooth for 2 min during a running half. | Digits still follow the anchor. | NOT TESTED |
| STEP-ACTIVE | While the half is running and the UI is alive, change the phone or watch clock by +120 s. | Expect hidden digits if `onPhoneTimeSetting` fires. A jump that stays on screen is a failed listener and must be recorded, not called `PROVEN_TIME`. | NOT TESTED |
| STEP-SLEEP | Change the source clock by +120 s while the app process is not running. | Record whether wake follows the stepped clock. That display can still be `UTC_ASSUMED` and wrong. Do not call it `PROVEN_TIME`. | NOT TESTED |
| BATTERY | Note start and end battery on the 90 min pass. | Percentage points. Screen-sleep is allowed. This does not certify the probe's 2-point observation. | NOT TESTED |

A row within 1 s of the reference is a functionality observation of this package. Founder approval is still required before merge.

## Outstanding risks

- An undetected civil-time step while the process is dead is not observable. The next paint stays `UTC_ASSUMED` and can be wrong.
- A detected phone-time callback during a running half fail-closes back to the last phase-change anchor. Painted time since kick-off or the last resume is discarded, and the digits hide. That is intentional. It is harsh if the callback fires without a real step.
- The 6-hour segment bound is a diagnostic reject, not a law of the game.
- The watch has no competition period-length control. New records store 45 minutes in `halfLimitMs`. A different length works only when that field is set.
- The App Service is not the segment clock. It still knows only the v1 files and is not started for a `utc_segment` session. A service left running from an older package can still mark the v1 file unverified. The v2 slots are the live record. Rollback to `sampler` then shows the v1 file, which may already be unverified.
- Fail-closed is durable only after the new slot reads back. A failed readback leaves the previous slot. Restart can show the previous healthy anchor.
- Corrupt or conflicting v2 slots do not fall back to a good v1 match. Kick-off stays refused until the slots are cleared.
- This clock is not Match Memory. Display UTC is not an authoritative event timestamp.
- The QR expires. After 28 Nov 2026, 14:32:44 Europe/Bucharest, preview again.
- No physical result in this file. Do not describe the integrated build as hardware-validated.
