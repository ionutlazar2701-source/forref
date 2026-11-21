# CLOCK-002 — Physical procedure

Programmatic read: **NOT TESTED**. No public call returns the native Stopwatch duration, so this procedure cannot produce a duration from SW-001.
System-UI facts already reported by the founder are **PROVEN** and are not repeated here as new measurements.
Documentation verdict: **NO-GO**. See `CLOCK_002_FINDINGS.md`.

Do not screen-scrape. Do not type a duration the screen did not show. Leave a cell blank when a step is skipped.

## Install

1. Scan the QR in `CLOCK_002_PREVIEW_QR.txt` with the Zepp app on the phone paired to the physical Amazfit Bip 6.
2. The app is SW-001 1.0.0, app id `30103`. It does not replace production FORREF (`29566`), the sensor lab (`30101`), or DUR-001 (`30102`).
3. Package `30103-SW-001-1.0.0-20261121101541.zab`, sha256 `75bd63592ddcdb86c88812151c67cbe871cc95b77d00a92a3767a5163bbc4574`, 8962 bytes. The QR expires 28 Nov 2026, 12:15:43 Europe/Bucharest (10:15:43 UTC). The file is gitignored.

## What the screen means

| Line | Meaning |
| --- | --- |
| Read | `NO_PUBLIC_READ`. The app has no duration field to fill. |
| Control | `LAUNCH_ONLY`. Open is a jump, not start, pause, resume, or reset. |
| Binding | `WATCHFACE_2_DIGITS`. That binding is not available in this Device App. |
| Check | `void` if `checkSystemApp` returned nothing. `throw` if it threw. |
| Open | `-` until the button. Then `void` or `throw`. |
| State | `TIME_UNKNOWN`. |

A line that contains a duration would be unexpected. Copy it exactly and do not treat it as match time.

## Retrieve attempt

1. Start the native Stopwatch and leave it running.
2. Return to the app list. Open SW-001.
3. Copy all six lines and, if a log is connected, the `SW001` line.
4. Tap OPEN STOPWATCH. The watch should leave SW-001 and show the system Stopwatch. That jump is not a read.
5. Open SW-001 again and copy the six lines. They still do not carry the system duration.

| Step | Copied screen | Result |
| --- | --- | --- |
| Open SW-001 while the system Stopwatch is running | | NOT TESTED |
| After returning from OPEN STOPWATCH | | NOT TESTED |

## System Stopwatch screen

These rows look at the native Stopwatch itself, not at SW-001. Compare it with an independent stopwatch. No result is filled in this repository.

| Id | What to do | System Stopwatch screen | Independent stopwatch | Result |
| --- | --- | --- | --- | --- |
| S30 | Leave the Stopwatch running, screen off for 30 seconds, then look at the Stopwatch. | | | NOT TESTED |
| S120 | Screen off for 2 minutes. | | | NOT TESTED |
| S600 | Screen off for 10 minutes. | | | NOT TESTED |
| S-APP | Open SW-001, then return to the Stopwatch. | | | NOT TESTED |

The founder already saw the Stopwatch continue while another app was open. That observation has no copied time, so these rows remain open.
