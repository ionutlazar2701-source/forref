# FORREF-CLOCK-SLEEP-001 root cause

Status: confirmed in the watch prototype and in the Zepp OS API 4.0 documents. The founder's Bip 6 callback sequence was not captured, so the device path is not certified.

## What the code does

`admitDisplay` treats a UTC step larger than `DISPLAY_CONTINUITY_MS` (2500) as `UNSAMPLED_GAP` and fail-closes. Elapsed time is `lastUtc - openStartUtc`. It advances only when something records a bounded observation. The Live page timer is `createTimer(1000, 1000, paintAll)`. That timer is paint, not the clock, and it stops when the page is destroyed.

`loadSession` previously marked every persisted running session `RECOVERY_REQUIRED`, and `app.js` mints a new `clockEpoch` on every `onCreate`. A process restart therefore could not restore exact digits.

## What the SDK documents

`Time.getTime()` is UTC milliseconds. It is not a monotonic sleep-inclusive clock. The SDK documents no `elapsedRealtime` equivalent.

`setWakeUpRelaunch` documents the default: after the screen turns off, the mini program exits in about 10 seconds and wake returns to the watch face. `relaunch: true` reopens the mini program. It does not measure elapsed time.

`createSysTimer` in a Device App Service is documented to run regardless of screen state. A tick is a scheduler callback, not a second of match time. App Service file writes are documented to succeed when the screen is off or in AOD. `start({ reload: true })` is the API 4.0 default and would restart the sampler across reboot. This build passes `reload: false`.

## What this build changes

A granted `device:os.bg_service` sampler records a UTC observation about once a second while a verified half is running. Exact digits continue only while successive observations stay inside 2500 ms. One paint across 5, 30, or 120 seconds, with no intermediate observation, stays `TIME_UNVERIFIED` and does not add the gap. A process recreate resumes exact digits only when the stored observation is still inside that window.

## What is not established

Whether Bip 6 keeps that service alive across the documented 10-second UI exit, whether `createSysTimer` fires during screen-off, and whether the off-screen file write is visible on relaunch. Those are the hardware gate. If they fail, the watch stays unverified. That is the correct outcome.
