# CLOCK recovery Bip 6 protocol

State: **NOT TESTED**. The 13-minute sleep pass and the two failures below are results of builds through 1.0.13. This package is 1.0.14 and has not been worn.

App id `29566`, version `1.0.14` (code 14). It includes the FIGMA-001 home screen and the recovery fix. Install `RECOVERY_PREVIEW_QR.txt`. Boot line `clock-p0-recovery` revision `ae4572d2b2434ffd03eeaa76922eb721edc2f97b`.

Package `29566-FORREF-1.0.14-20261126200643.zab`, 299263 bytes, sha256 `c769da2da89a7cd69d22fc1ee7fe342af181ad3c1e8b66d480074621bc31bad5`. The QR expires 3 December 2026, 22:06:46 Europe/Bucharest (20:06:46 UTC).

## What to record

Keep the developer log. Copy `FORREF_CLOCK_CADENCE` and `FORREF_CLOCK_SLEEP recover=`. Hidden digits remain `TIME_UNKNOWN`. A smooth face is not `PROVEN_TIME`.

| Test | Steps | Pass | Result |
| --- | --- | --- | --- |
| SLEEP-13 | Kick off. Screen off for 13 minutes. Wake into Live. | Face matches a reference stopwatch within 1 s. Then five cadence lines with `dt` 700–1400 and `step=1`. | NOT TESTED on 1.0.14. 1.0.13 passed the elapsed time. |
| REOPEN | Leave FORREF. Reopen Live Fixture after about 30 seconds. Repeat after 2 minutes and after 13 minutes. | Each reopen shows the anchor time. `recover=` is not an unverified failure. The face is not `TIME_UNKNOWN`. | NOT TESTED. 1.0.13 failed this with TIME_UNVERIFIED. |
| CADENCE | Leave the screen on for 30 s. Then sleep, return from Goal, and sleep again. | No stretch stays on `step` 2. `CALLBACK_2S` is `dt` near 2000 with `step` 2. `RENDER_SKIP` is `dt` near 1000 with `step` 2. | NOT TESTED. 1.0.13 still stepped by two seconds. |
| BACKWARD | Do not change the phone clock during these rows. | A row is valid only while the civil clock was left alone. | NOT TESTED |
| HOME | Open the app. | Upper half opens match selection. Lower half opens training. | NOT TESTED |
| BATTERY | Note percent at the start and end of the 13-minute row. | One JavaScript wake per visible second. No new screen-off timer. | NOT TESTED |
