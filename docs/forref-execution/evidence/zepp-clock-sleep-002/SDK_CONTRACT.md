# SDK contract — clock sleep 002

Read on 20 Nov 2026 from the Zepp OS API 4.0 reference. The 1.0.4 build did not follow these contracts.

| API | Contract | 1.0.4 | 1.0.5 |
| --- | --- | --- | --- |
| `queryPermission` | Synchronous. Returns `Array<number>` in permission order. `0` not authorized, `1` unknown permission, `2` authorized. No callback parameter. | Passed a callback and ignored the return value. `pending` stayed true, so `start` never ran. | Reads the returned array. `2` starts. `0` calls `requestPermission`. `1` logs `perm=unknown` and does not start. |
| `requestPermission` | Returns a number. `0` means the user dialog is in progress and the callback receives the result array. `1` means no request can be made. `2` means already authorized. | Nested under the query callback, so it was never reached. | Called only after a synchronous `0`. Return `2` starts immediately. Return `1` blocks. Return `0` waits for the callback. |
| `start` | `file` and `complete_func` required. Return `0` is success. Callback `result` is boolean. `reload` defaults to `true` at API 4.0. | `reload: false` was already set, but start was unreachable. | Same file, `reload: false`. Running becomes true on return `0` or callback `true`. |
| `stop` | `file` and `complete_func` required. Return `0` means closed. Callback `result` true means success. | Called `stop()` with no arguments, then set `running` false anyway. | Passes `file` and `complete_func`. A throw or a false callback leaves `running` true. |
| `getAllAppServices` | Returns the running service list. | Not called. | Logged on start and stop. A listed service is not started again. |

`Time.getTime()` remains UTC. `createSysTimer` remains a scheduler. `DISPLAY_CONTINUITY_MS` remains 2500.

Sources:

- https://docs.zepp.com/docs/reference/device-app-api/newAPI/app/queryPermission/
- https://docs.zepp.com/docs/reference/device-app-api/newAPI/app/requestPermission/
- https://docs.zepp.com/docs/reference/device-app-api/newAPI/app-service/start/
- https://docs.zepp.com/docs/reference/device-app-api/newAPI/app-service/stop/
- https://docs.zepp.com/docs/reference/device-app-api/newAPI/app-service/getAllAppServices/
- https://docs.zepp.com/docs/reference/device-app-api/newAPI/display/getSettings/
