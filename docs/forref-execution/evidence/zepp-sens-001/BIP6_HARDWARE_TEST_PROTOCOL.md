# Bip 6 hardware test protocol

**PHYSICAL GATE PENDING.** Cursor did not operate the Founder's Amazfit Bip 6. Do not treat the simulator session as this protocol.

## Physical install gate

**PHYSICAL_INSTALL_PENDING.** This cloud environment has no Zepp login. `zeus status` reports `login status: no login`. No install QR was generated.

On 18 Nov 2026 at 00:16 Europe/Bucharest, `zeus preview -t "Amazfit Bip 6"` from `apps/forref_sensor_lab` printed only:

```text
[ℹ] The login page has been opened in the default browser.
```

It printed that line twice and then returned. `zeus status` stayed `no login`. That login page is not an install QR.

### Founder workflow

Run this on the Founder's computer, in the sensor-lab directory of this branch:

```bash
cd apps/forref_sensor_lab
zeus login
zeus status
zeus preview -t "Amazfit Bip 6"
```

`zeus login` opens the browser (`--browser` defaults to true). Complete the Zepp account login there. If no browser is available, run `zeus login --no-browser` and open the URL the CLI prints. `zeus status` must show a logged-in account before preview.

`zeus preview -t "Amazfit Bip 6"` is the command that can print the install QR after login. Scan that QR from the Zepp app on the phone paired to the physical Bip 6, with developer mode enabled. On the watch, open `FORREF SENS` (app id 30101). Production FORREF is app id 29566. The home line must read `STOPPED — NOT A MATCH` before `START`.

`zeus preview --local` serves a package over HTTP on the same LAN. It was not used, and a URL from this cloud VM is not a physical install path.

`zeus build` can write a gitignored `.zab` without login. A package file is not a QR. Do not commit `dist/`.

## Before every stage

- Outdoor sky for GNSS stages. A window sill is not the trial.
- Phone Bluetooth may be on for the install. After install, do not depend on the phone. The lab does not call the network.
- Note battery percent from the watch before `START`.
- `START` only when the home line says `STOPPED — NOT A MATCH`.
- Do not open production FORREF during the sample. A later navigation test is explicit in stage B.
- Do not photograph the status screen if it shows a real coordinate or a real pulse. `TRACK` and `HEAT` are the shareable screens: they show experimental meters, gaps, and either `HEAT MAP UNAVAILABLE` or `NO FIELD CALIBRATION`.

## Stage A — 5 minutes stationary

Do this only after `FORREF SENS` is installed on the physical Bip 6. The simulator session is not Stage A.

1. Stand still outdoors, with open sky.
2. Read the battery percent on the watch and write it in a private note.
3. Open `FORREF SENS`. Confirm `STOPPED — NOT A MATCH`.
4. Press `START`. Leave this app in the foreground for 5 minutes. Leave the screen on. Do not press `START` again.
5. Press `STOP`.
6. Open `STATUS`. In the private note, write whether the GNSS line says `FIX` or `NO FIX`, and whether heart rate says `HR PRESENT` or `HR UNAVAILABLE`. Leave the coordinate and the BPM on the watch. Do not copy them into git, chat, or a screenshot that will be uploaded.
7. Open `TRACK`. Write the session id (`SESSION LAB-…`), the experimental meter reading, whether max speed is unavailable, and the gap count. Write the heart-rate line as `HR SAMPLES valid/total` or `HR UNAVAILABLE`. Write `HR TIME` separately. `HR SAMPLES` is a count ratio. It is not the percentage of the 5 minutes that had a pulse.
8. Write the battery percent again.

A no-fix result is a valid measurement. Pass for this stage is that private note. It does not certify distance, speed, or a medical reading.

## Stage B — 15 to 20 minutes moving

1. `START` a new session.
2. Walk or run for 15–20 minutes. Paired 1 Hz GNSS and heart-rate lines fill the journal at about 18 minutes 54 seconds. If the home line changes to `STORAGE FULL`, press `STOP` and record that time. That stop is the storage cap.
3. Turn the screen off for about one minute, then wake the watch and return to the lab without pressing `START` again.
4. Once, leave the lab with the watch Back key or by opening another app, then return.
5. `STOP`.
6. On `TRACK`, record accepted versus discarded if the screen shows them as gaps and missing seconds, the experimental distance, and whether max speed is unavailable.
7. Battery percent again.

Interpret a hole only from the gap line. `APP_EXIT` after opening Status is navigation. `DISPLAY_OFF` is the screen-off mark. Neither is physical power loss. If the track shows one large gap covering the screen-off minute, GNSS did not continue through that interval.

## Stage C — not an endurance test

The journal cannot hold a 90-minute session at 1 Hz GNSS plus 1 Hz heart rate. The measured cap is 1,134 seconds of those pairs, then `STORAGE FULL`. Do not run a 45–90 minute trial to claim endurance readiness. Screen-off continuity remains a Stage B question.

## After the session

`DELETE LOCAL`, then `CONFIRM DELETE`, before any export or screenshot sync. The research file is only for the watch. Do not attach it to a GitHub issue or pull request.

## What this protocol cannot certify

It does not certify D1, official distance, official maximum speed, a medical reading, or match minutes.
