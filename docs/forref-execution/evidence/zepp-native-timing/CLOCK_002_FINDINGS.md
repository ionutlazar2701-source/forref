# CLOCK-002 — Native Stopwatch access

Documentation verdict for a programmatic read: **NO-GO**.
Founder system-UI observations: **PROVEN** for two facts, with no recorded duration.
Programmatic read on a watch: **NOT TESTED**. There is no public read to execute.
Recommendation: **NO-GO**.

Baseline: PR #62, `cursor/clock-001-native-timing-4ae8` at `2a58c60d21728e70a4b1f67e359b7ceed8fc1509`.
This branch does not modify Match Core, Match Memory, or production app id 29566.

## Founder evidence

On a physical Amazfit Bip 6 the founder confirmed:

- An active Running workout blocks access to other apps.
- The native Stopwatch can keep running while another app is open.

Those two facts are **PROVEN** as system-UI observations. The founder did not supply a duration, a stopwatch comparison, or an error. They are not a programmatic read, and they do not establish a one-second bound.

Concurrent Running plus DUR-001 is no longer the experiment.

## Capability matrix

| Capability | Class | Result | Evidence |
| --- | --- | --- | --- |
| `hmUI.data_type.STOP_WATCH` | DOCUMENTED | Watchface display only. Data range is 2 digits, minutes or seconds. | [data_type](https://docs.zepp.com/docs/watchface/api/hmUI/widget/data_type/) |
| `TEXT_IMG` `type` | DOCUMENTED | Draws the bound data as pictures. Setting `text` disables `type`. `setProperty` `TEXT` sets the picture text. | [TEXT_IMG](https://docs.zepp.com/docs/watchface/api/hmUI/widget/TEXT_IMG/) |
| `getProperty` | DOCUMENTED | Widget configuration. The watchface example returns angle, width, and height. It does not return a stopwatch duration. | [getProperty](https://docs.zepp.com/docs/watchface/api/hmUI/getProperty/) |
| Device App `TEXT` | DOCUMENTED | `getProperty` covers position, size, color, alignment, font, and the text the app set. There is no `data_type` and no `STOP_WATCH`. | [TEXT](https://docs.zepp.com/docs/reference/device-app-api/newAPI/ui/widget/TEXT/) |
| `launchApp` / `checkSystemApp` with `SYSTEM_APP_STOPWATCH` | DOCUMENTED | Launch only. Both functions return void. | [launchApp](https://docs.zepp.com/docs/reference/device-app-api/newAPI/router/launchApp/) |
| Start, pause, resume, reset | DOCUMENTED | No public method. | Same launch page |
| Read elapsed duration while FORREF is in front | DOCUMENTED | No public read. | data_type and TEXT pages |
| Stopwatch keeps running behind another app | PROVEN | Founder saw this on Bip 6. No value was copied. | This file |
| Running blocks other apps | PROVEN | Founder saw this on Bip 6. | This file |
| Programmatic value after sleep, wake, or reopen | NOT TESTED | No read exists to call. The system Stopwatch screen was not timed here. | `CLOCK_002_HARDWARE_TEST.md` |
| Simulator duration | SIMULATOR | Not run. | — |

## Display is not a value

A watchface can draw `STOP_WATCH` as two digits. The page does not say which unit those digits are, and two digits cannot represent `1:05:34`. `getProperty` on a Device App text widget returns the string that widget was given. Reading that string back is reading the app's own configuration. It is not the native Stopwatch.

`SW-001` is app id `30103`, version 1.0.0. It calls only `checkSystemApp` and, on a button, `launchApp`. Both are documented as void. The screen keeps `TIME_UNKNOWN`. It does not count seconds and it does not scrape pixels.

Package `30103-SW-001-1.0.0-20261121101541.zab`, sha256 `75bd63592ddcdb86c88812151c67cbe871cc95b77d00a92a3767a5163bbc4574`, 8962 bytes. QR expiry 28 Nov 2026, 12:15:43 Europe/Bucharest (10:15:43 UTC). No watch callback has been copied.

## Recommendation

**NO-GO** for reading the native Stopwatch into FORREF.

The system Stopwatch can keep running behind another app. That was seen. No public API returns that elapsed duration, controls it, or preserves a readable value across sleep. A two-digit watchface binding is a display, not match time.

Reopen only if a public page documents a Device App read of the native Stopwatch duration, including its unit and its behavior across sleep, and a physical trial stays within one second of an independent stopwatch.

## Checks

Sensor lab, DUR-001, and SW-001: 50 tests passed. `./tool/verify_cloud.sh` passed: match core 377, persistence 92, phone 126. Those runs do not measure a watch. Simulator: not run. Physical programmatic read: not tested.
