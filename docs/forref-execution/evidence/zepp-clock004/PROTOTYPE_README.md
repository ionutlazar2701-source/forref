# FORREF CLOCK-004 — UTC Segment Research Prototype

Independent experiment targeting Amazfit Bip 6; **NOT** integrated into production FORREF or Match Core.

This folder contains a Zepp OS Device App scaffold (`apps/forref_chron004_probe`), a pure JavaScript state machine, a two-slot checksum/readback store, and Node tests.

## Research question
Can a durable UTC segment anchor reconstruct match elapsed time after 30 s / 2 min / 10 min sleep without adding one second per JavaScript callback? Yes by arithmetic **assuming** UTC does not step. This is a testable design, **not proof that it is safe to display as PROVEN_TIME**.

## Prior art in repository
- PR #43 originally used `Time.getTime()` deltas.
- PR #54/56/61 use `DISPLAY_CONTINUITY_MS=2500`, requiring an intermediate sample inside 2.5 s; late screen wake causes `UNSAMPLED_GAP`.
- PR #62/63 explored native Running/Stopwatch integration, and did not demonstrate a readable native stopwatch.

## What differs
- Persist the `anchorUtc` on every phase transition.
- Reconstruct on paint after restart without relying on periodic callback execution.
- Label reconstructed duration `UTC_ASSUMED`; never confuse it with `PROVEN_TIME`.
- `onPhoneTimeSetting` detected while the runtime is alive invalidates time; a step while runtime is asleep may go undetected.
- Two independent checkpoint slots with checksum/readback reduce partial-file corruption (not a guarantee of flash-level durability).
- Cosmetic `setInterval()` refresh is a negative-control counter, not the clock.

## Test
```bash
cd apps/forref_chron004_probe
npm test
```

## Known blockers and limits
1. No hardware package built: `zeus preview` or Zepp CLI still needs to build on developer workstation and verify actual APIs/layout.
2. No physical Bip 6 sleep/clock-change observations recorded.
3. A hidden civil clock step while the app is asleep cannot be detected by one UTC observation. It MUST NOT silently become FORREF `PROVEN_TIME`.
4. The POC uses a standalone app id 30104 for research; verify app registration and package installation before attempting to install.
5. This app intentionally has limited controls; suspension, extra time and production Match Memory are out of scope.
6. It must not be cherry-picked wholesale into production; use observations to design a separate temporal authority ADR.

## Source documentation
- https://docs.zepp.com/docs/reference/device-app-api/newAPI/sensor/Time/
- https://docs.zepp.com/docs/reference/device-app-api/newAPI/display/setWakeUpRelaunch/
- https://docs.zepp.com/docs/reference/device-app-api/newAPI/fs/writeFileSync/
- https://docs.zepp.com/docs/reference/device-app-api/newAPI/sensor/Screen/
- https://docs.zepp.com/docs/reference/device-app-api/newAPI/display/setPageBrightTime/
