# Simulator report

Guest session 17 Nov 2026, 20:22–20:25 Europe/Bucharest. The simulator clock was UTC. Unedited sensor lines, with no coordinates and no pulse values, are `guest/console.txt`.

Zeus CLI connected to `127.0.0.1:7650`. `zeus status` reported `login status: no login` and `simulator connect status: connected`. Simulator package `2.1.2`. QEMU norflash `~/.zepp/emulator_cache/4ae8ec66a7e2d342faf040652f4f41ff/norflash.bin` (Bip 6). The simulator process was left running.

`zeus dev -t "Amazfit Bip 6"` from `apps/forref_sensor_lab` bundled 6 JS files and refreshed the guest. Device sources included `10158337`.

## What the guest showed

Home (`guest/home.png`): `FORREF SENS`, `SENS LAB`, `STOPPED — NOT A MATCH`, and the eight controls including `HR SERVICE — NO GNSS`.

`START` wrote `LIFECYCLE START` and then GNSS rows `seq=2` through `seq=11` with `status=A`. Those rows are simulator GNSS status. They are not a hardware fix and not a personal track. The console lines do not contain coordinates. The status screenshot in `guest/status-redacted.png` has the coordinate row covered. Visible labels there are `FIX`, `HR UNAVAILABLE`, `DISTANCE UNIT UNRESOLVED`, `BAT 88%`, and `NOT A MATCH RECORD`. `BAT 88%` is the simulator battery reading.

Heat (`guest/heat.png`): `NO FIELD CALIBRATION`, `NOT A MATCH RECORD`, `EXPERIMENTAL`. No map was drawn. The page chose calibration-missing because the simulator had status-`A` samples, which is the honest branch. It did not invent a pitch.

Opening Status destroyed home and logged `LIFECYCLE APP_EXIT`. GNSS lines stopped at that boundary. That is in-app navigation, not screen-off and not power loss.

## What the guest did not show

- No physical screen-off interval. That observation is **BLOCKED**.
- No hardware heart-rate callback. The guest showed `HR UNAVAILABLE`.
- No Workout Extension.
- The HR-only App Service button was not used as a continuity proof. `reload: false` is set so a research service is not persisted across reboot.

Synthetic sensor numbers from this guest are not physiology and not a GNSS survey.
