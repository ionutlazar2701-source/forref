# Zepp capability matrix — clock sleep

Labels: CODE = this repository. DOC = Zepp OS API 4.0 documentation read for this task. DEVICE = Amazfit Bip 6. No device trace was captured.

| Capability | CODE | DOC | DEVICE |
| --- | --- | --- | --- |
| Page `createTimer` stops when Live is destroyed | yes | page timers are UI-scoped | none |
| UTC step over 2500 ms fail-closes | yes, constant unchanged | n/a | none |
| Running restore with no fresh `now` is `RECOVERY_REQUIRED` | yes | n/a | none |
| Restore inside 2500 ms keeps the open segment | yes, `CONTINUITY_RESUMED` | n/a | none |
| `Time.getTime()` is UTC, not monotonic | used as UTC only | UTC milliseconds | none |
| Monotonic sleep-inclusive clock | not in the SDK | not documented | none |
| Default screen-off exits the mini program in about 10 s | `setWakeUpRelaunch({ relaunch: true })` requested | documented default | none |
| Wake relaunch measures elapsed time | no | no | none |
| `createSysTimer` runs with the screen off | scheduled at 1000 ms inside the App Service | documented | none |
| App Service needs `device:os.bg_service` | permission declared; deny does not write | user grant required; one continuous service system-wide | none |
| Service file write while the screen is on | best effort; a failed readback does not invent time | documented to work when the screen is off or AOD | none |
| `start` reload across reboot | `reload: false` | default `true` at API 4.0 | none |
| `onPhoneTimeSetting` | logged only | phone time-setting callback; not a complete clock-change detector | none |
| Workout / GPS moved into the service | no | high-power sensors are forbidden in the service | none |

Sources read:

- https://docs.zepp.com/docs/reference/device-app-api/newAPI/sensor/Time/
- https://docs.zepp.com/docs/reference/device-app-api/newAPI/timer/createSysTimer/
- https://docs.zepp.com/docs/guides/framework/device/app-service/
- https://docs.zepp.com/docs/reference/device-app-api/newAPI/app-service/start/
- https://docs.zepp.com/docs/reference/device-app-api/newAPI/display/setWakeUpRelaunch/
