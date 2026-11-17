# Capability matrix

Task file `TASK_CURSOR_SENS_001_BIP6_SENSOR_FEASIBILITY.md`, file id `1DVpi7YZ_km6-_tDAmdX-Z-WqKdNgoRft`. SHA-256 of the downloaded bytes: `cc029a91addc686e127333df30d6016730bf3566cd9b1c3bb18ccb9c0318d8f3` (9955 bytes, match).

Watch baseline remains PR #48 at `4510c948439759d08c1dde4d6c2fb503d98b2cb8`. This lab does not modify that branch.

## What was measured

| Path | GNSS | Heart rate | Distance | Battery | Evidence |
| --- | --- | --- | --- | --- | --- |
| Device App, screen on | `Geolocation` start / onChange / stop. Latitude and longitude are read only when `getStatus()` is `A`. | `HeartRate.onCurrentChange` / `offCurrentChange`. | `Distance.onChange`. Raw number stored. Unit and session attribution stay `UNRESOLVED`. | `Battery` percent folded onto the GNSS sample. | Code plus Bip 6 guest. Simulator status `A` is not a hardware fix. |
| App Service | Not called. Zepp documents Geolocation as a high-power sensor unavailable in App Service. | `app-service/hr_only.js` imports HeartRate only. The home control stops GNSS before `start({ reload: false })`. | Not used. | Not used. | Source contains no `Geolocation` string. Service was not left running across reboot. |
| Workout Extension | Not implemented. | Not implemented. | Not implemented. | Not implemented. | Published Zepp OS 3.5 Workout Extension devices do not name Bip 6. |

`setWakeUpRelaunch` is not used. A wake relaunch would not prove continuous GNSS.

## Guest identity, not hardware identity

Bip 6 QEMU guest, 17 Nov 2026, 20:22–20:25 Europe/Bucharest (simulator clock UTC):

`FORREF_SENS_DEVICE page=home width=390 height=450 shape=RECT screenShape=0 deviceSource=10158337 deviceName=Bip 6`

## Decision

`HARDWARE_EVIDENCE_PENDING`

Foreground GNSS is wired. Screen-off survival on a physical Bip 6 was not measured. App Service cannot supply background GNSS. A Workout Extension is not a Bip 6 plan until the device is on the published support list and a hardware session shows it.
