# Root cause — CLOCK-CONTINUITY-003

Physical input: FORREF 1.0.5 on Amazfit Bip 6. The background permission prompt appeared. The match clock still failed during screen sleep, and it also failed while the referee recorded a Goal, a Card, or a Substitution. This report separates what the 1.0.5 source and the Zepp OS API 4.0 contract confirm from what a device log would still have to show. No Bip 6 log from that run was available, so nothing here claims that `createSysTimer` fired on the watch.

`DISPLAY_CONTINUITY_MS` stays 2500. A wall-clock gap with no admitted observation is `UNSAMPLED_GAP`. The closed elapsed does not grow, and the digits stay null.

## A. Foreground navigation — confirmed

1.0.5 sampled match time in one place: `createTimer(1000, 1000, paintAll)` inside `page/gt/live/index.page.js`. `onDestroy` stopped that timer and persisted the session. Event, Player, and Review did not call `liveFrame`, `sample`, or `createTimer`.

Goal, Card, and Substitution navigate Live → Event → Player → Review and back. The screen stays on, so the App Service is not the writer for that interval: Zepp documents `@zos/fs` writes from an App Service only while the screen is off or in AOD. After more than 2500 ms away from Live, the next `prepareFrame` saw a UTC step wider than the window and fail-closed `UNSAMPLED_GAP`.

That combination is the confirmed cause of the capture-navigation failure. The page paint timer was acting as the only foreground observer. It is not temporal authority, and it dies with the Live page.

What is not confirmed: whether the App Service process kept an in-memory tick during those pages. It could not persist one while the screen was on, and the next Live admission does not accept an unpersisted gap.

## B. Screen-off — confirmed defects and open hypotheses

Confirmed from 1.0.5 code and the current App Service guide:

- The permission prompt means `requestPermission` ran. It does not prove the callback status was `2`, that `start` returned `0`, or that the service stayed listed.
- `services=absent` logged an empty running list once and returned. A service that died, or that never appeared in `getAllAppServices`, was not started again.
- The service module imported `clock_device.js`, which constructs `LocalStorage` and commits only when the data file and the LocalStorage key read back equal. `@zos/storage` is not in the App Service API table. A throw at import prevents the service from loading. A failed key write makes `commitSession` return `READBACK`, leaves the file and the key different, and the next UI `loadSession` returns `CONFLICT` or `RECOVERY_REQUIRED`. The gap is not added.
- `@zos/fs` writes in the service are specified for screen-off and AOD only. A tick while the screen is still on cannot be the durable checkpoint.
- `createSysTimer` in an App Service is documented to be scheduled regardless of screen state. The tick is a scheduler. Elapsed time still comes only from successive UTC observations inside 2500 ms.

Hypotheses, until a 1.0.6 log shows otherwise:

- The founder dismissed the permission dialog, or the callback was not status `2`, so `start` never ran.
- `start` returned a non-zero code.
- `createSysTimer` did not fire on this Bip 6 firmware while the screen was off.
- The file write failed even with the screen off.
- The UI persisted a stale in-memory session over a newer service checkpoint on wake.
- The mini program exited after the documented screen-off window and `setWakeUpRelaunch` did not bring back a running service.

None of those hypotheses is certified by the cloud tests. Cloud PASS is not a Bip 6 result.

## Boundary

One admission function, `liveFrame` / `admitDisplay`, is the only way elapsed time advances. Two schedulers call it:

- A Device App `createTimer` created from `app.js` `onCreate` and stopped from `onDestroy`. It is not owned by Live, Event, Player, or Review. While the process is alive and the screen is on, it can write the file, the mirror, and LocalStorage. The Live paint timer still calls the same function while Live is visible. It is a repaint, not the authority.
- The App Service `createSysTimer` for screen-off. It writes `forref_clock001c_state.json` and `forref_clock001c_state.mirror.json` through `@zos/fs` only. It does not import LocalStorage. `loadSession` accepts the file when it matches either LocalStorage or the mirror. A file/key mismatch with no matching mirror stays `CONFLICT`.

If neither scheduler produced a chain inside 2500 ms, the clock fail-closes. The window is not widened. Pause and half-time on a verified clock still freeze the last good elapsed. After `UNSAMPLED_GAP`, those intents stay unverified and do not fold the gap in.
