# SENS V2 founder retest

Use this only after the simulator notes in `EVIDENCE_MATRIX.md`. Remove the previous FORREF SENS build from the watch before installing this one. Stop on lag, heat, or a restart. This is not an endurance trial and it does not certify screen-off GPS.

1. Confirm the watch is responsive with the old lab removed.
2. Install only `SENS V2` `2.0.0` (app id `30101`) from the preview QR that expires `2026-11-25 21:13:14` UTC (`23:13` Europe/Bucharest). Do not install `1.0.0`.
3. Open the app. The title must read `SENS V2`. GPS must read stopped before any button. If the watch hesitates here, stop.
4. Tap `HR ONLY`. The distance line must read `NO GPS / DISTANCE UNAVAILABLE`. Leave it for 30 seconds. Then tap `STOP` and confirm GPS is stopped.
5. If step 4 stayed responsive, tap `START SESSION` for 30 seconds. Searching is an expected state. Do not keep the session running because the first samples are weak.
6. Tap `STOP`, then `DIAGNOSTICS`. The page must say `NOT SAVED` and `NOT A MATCH RECORD`. Do not photograph coordinates or a pulse value.
7. Delete the app if the watch misbehaves. Do not start a long outdoor recording from this build.
