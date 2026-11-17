# Bip 6 hardware test protocol

**PHYSICAL GATE PENDING.** Cursor did not operate the Founder's Amazfit Bip 6. Do not treat the simulator session as this protocol.

## Install

Developer login is absent in this cloud environment, so no preview QR was produced.

On a machine that already has `zeus login`:

```bash
cd apps/forref_sensor_lab
zeus preview
```

Without login, a local package can still be built and is gitignored:

```bash
cd apps/forref_sensor_lab
zeus build
```

This environment produced `dist/30101-FORREF_SENS-1.0.0-20261117182724.zab` (20:27 Europe/Bucharest). That file is not committed. Simulator install that was actually run:

```bash
cd apps/forref_sensor_lab
zeus dev -t "Amazfit Bip 6"
```

Install `FORREF SENS` (app id 30101) in Zepp developer mode. Confirm the watch shows app id 30101 and not production app id 29566. Grant location, heart rate, distance, and local storage when the OS asks. Sampling still waits for `START`.

## Before every stage

- Outdoor sky for GNSS stages. A window sill is not the trial.
- Phone Bluetooth may be on for the install. After install, do not depend on the phone. The lab does not call the network.
- Note battery percent from the watch before `START`.
- `START` only when the home line says `STOPPED — NOT A MATCH`.
- Do not open production FORREF during the sample. A later navigation test is explicit in stage B.
- Do not photograph the status screen if it shows a real coordinate or a real pulse. `TRACK` and `HEAT` are the shareable screens: they show experimental meters, gaps, and either `HEAT MAP UNAVAILABLE` or `NO FIELD CALIBRATION`.

## Stage A — 5 minutes stationary

1. Stand still outdoors.
2. `START`. Leave the lab in the foreground for 5 minutes with the screen on.
3. `STOP`.
4. Open `STATUS` only on the watch. Record, in a private note, whether the line says `FIX` or `NO FIX`, and whether heart rate says `HR PRESENT` or `HR UNAVAILABLE`. Do not copy the coordinate or the BPM into git, chat, or a screenshot that will be uploaded.
5. Open `TRACK`. Record the experimental meter reading, whether max speed is unavailable, the gap count, and the heart-rate coverage percent.
6. Write the battery percent again.

Pass for this stage is a private note that a fix and a pulse were or were not present. A no-fix result is a valid measurement.

## Stage B — 15 to 20 minutes moving

1. `START` a new session.
2. Walk or run for 15–20 minutes.
3. Turn the screen off for about one minute, then wake the watch and return to the lab without pressing `START` again.
4. Once, leave the lab with the watch Back key or by opening another app, then return.
5. `STOP`.
6. On `TRACK`, record accepted versus discarded if the screen shows them as gaps and missing seconds, the experimental distance, and whether max speed is unavailable.
7. Battery percent again.

Interpret a hole only from the gap line. `APP_EXIT` after opening Status is navigation. `DISPLAY_OFF` is the screen-off mark. Neither is physical power loss. If the track shows one large gap covering the screen-off minute, GNSS did not continue through that interval.

## Stage C — 45 to 90 minutes, only after A and B

Run this only if stage B shows GNSS samples on both sides of a screen-off interval with a quantified gap, or shows samples continuing through it. If stage B shows a single stall for the whole screen-off period and no later fixes, stop. Do not start the endurance trial.

If you do run it:

- Expect `STORAGE FULL` if one-hertz samples exceed 4096 lines or 1 MB. That is the storage bound.
- Record battery delta, the first and last sample you can see on Track, gap count, missing seconds, experimental distance, max-speed availability, and heart-rate coverage.
- Coverage is not a medical result.

## After the session

`DELETE LOCAL`, then `CONFIRM DELETE`, before any export or screenshot sync. The research file is only for the watch. Do not attach it to a GitHub issue or pull request.

## What this protocol cannot certify

It does not certify D1, official distance, official maximum speed, a medical reading, or match minutes.
