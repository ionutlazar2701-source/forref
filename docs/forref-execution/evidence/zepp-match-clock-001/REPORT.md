# FORREF Zepp match clock 001

Prototype watch-client instrument on `apps/forref_watch_zepp`. This is not Match Memory, not a second writable Match Authority, and not a D1 commit. Elapsed digits are an observed UTC wall-clock reading. The screen labels that reading as a prototype. `45:00` and `90:00` are display marks. They do not end a period.

## Branch

- Branch: `cursor/zepp-match-clock-001-30fd`
- Base: `cursor/zepp-native-baseline-30fd` at `bc7a67d45a3a2f8bb54d29f81859d3e01e63904e`
- Head: recorded in the commit that adds this report
- Match Core, `packages/match_core`, the phone authority path, schema, and D1 settings were not modified

## What the referee can do

```text
READY
  KICK_OFF -> FIRST_HALF_RUNNING
FIRST_HALF_RUNNING
  PAUSE -> FIRST_HALF_PAUSED
  END_FIRST_HALF -> HALF_TIME
FIRST_HALF_PAUSED
  RESUME -> FIRST_HALF_RUNNING
  END_FIRST_HALF -> HALF_TIME
HALF_TIME
  START_SECOND_HALF -> SECOND_HALF_RUNNING
SECOND_HALF_RUNNING
  PAUSE -> SECOND_HALF_PAUSED
  FULL_TIME -> FULL_TIME
SECOND_HALF_PAUSED
  RESUME -> SECOND_HALF_RUNNING
  FULL_TIME -> FULL_TIME
FULL_TIME
  no further playing transition
```

A repeated intent id is ignored. An illegal transition leaves the phase unchanged and shows NOT APPLIED. Opening Ready or Live does not kick off. FULL TIME does not navigate to Finish and is not COMPLETED. Undo of full time is omitted.

While a period is running, the displayed second is `floor` of the UTC delta since the open segment started, after each accepted sample. A late callback adds the real delta. It does not add one second per callback. A backward step, a forward gap above 120 seconds, a timezone or sleep discontinuity, or a new process epoch while running closes the last accepted sample and shows TIME UNVERIFIED. The gap is not painted as exact time.

Regulation presentation:

- 1st half at or under 45:00 is `MM:SS`. Past that mark it is `45 + MM:SS`.
- 2nd half starts at a `45:00` label. The stored 1st-half elapsed stays on the 1st half. A 1st half of 47:15 still opens the 2nd half at `45:00`.
- Past 90:00 the label is `90 + MM:SS`.
- Half-time and full time freeze. The break does not add playing seconds.

## Clock source

`@zos/sensor` `Time.getTime()` returned UTC milliseconds on this simulator (`SRC|1793911647542`). That value is wall time. No documented monotonic source was found, and none was invented. `@zos/timer` `createSysTimer` did not fire on this page. `createTimer(1000, 1000, callback)` did. The callback only schedules a resample. It is not temporal authority. No background App Service and no screen-wake permission were added.

Permission added: `device:os.local_storage`, beside the existing `data:os.device.info`.

Prototype journal files, distinct from the storage probe:

- `forref_clock001b_state.json`
- LocalStorage key `forref_clock001b_state`

A transition writes both copies and accepts the transition only when both read back the same checksummed payload. The acknowledgement string is `READBACK_ONLY_NOT_D1`. A tick does not write. Disagreement, truncation, or a thrown read fails closed and does not show a precise running clock. If both copies are absent, the screen is a fresh READY and does not claim a prior match existed.

## Device profile

| Source | Identity |
| --- | --- |
| Zeus preview target | Amazfit Active 3 Premium, device sources 10944768, 10944769, 10944771, 10948867 |
| Firmware actually running | Amazfit Active Max, `deviceSource=10813699`, 480×480 ROUND, Simulator 2.1.2 |
| QEMU | pid 195713, still the existing process after the Apps-list recreation |

These two names are not collapsed. Neither is a certified match watch.

## Simulator session

Guest locale `en-US` from the OS. Route used: Home → Officiate → Riverside fixture → Kick-off prep → Open live fixture.

Second session, after the page timer was switched to `createTimer` (UTC console times, 5 Nov 2026):

| UTC | Europe/Bucharest | Evidence |
| --- | --- | --- |
| 20:53:57 | 22:53:57 | `LOAD|RDY>RDY|…|00:00|FROZEN_OBSERVED` and `TIMER|createTimer` |
| 20:53:59 | 22:53:59 | `APPLIED|RDY>H1R|…|00:00` |
| 20:54:00–20:54:57 | 22:54:00–22:54:57 | Ticks through `00:58`. A delayed callback stepped `00:36` to `00:38` and `00:56` to `00:58` |
| 20:54:57 | 22:54:57 | `APPLIED|H1R>H1P|…|00:58|FROZEN_OBSERVED` |
| 20:55:22 | 22:55:22 | Resume. No tick between 20:54:57 and 20:55:22 |
| 20:55:28 | 22:55:28 | Live page destroyed. Ready shown. Live reopened in the same process |
| 20:55:31 | 22:55:31 | Running continued at `01:08`, not reset to `00:00` |
| 20:55:35 | 22:55:35 | `APPLIED|H1R>HT|…|01:11|FROZEN_OBSERVED`. No tick until 20:55:48 |
| 20:55:48 | 22:55:48 | `APPLIED|HT>H2R|…|45:00` |
| 20:55:50–20:55:57 | 22:55:50–22:55:57 | 2nd half ticks `45:01` … `45:08` |
| 20:55:57 | 22:55:57 | `APPLIED|H2R>FT|…|45:08|FROZEN_OBSERVED` |
| 20:57:43 | 22:57:43 | Apps-list recreate: `live onDestroy`, `APP onDestroy`, `APP onCreate epoch=e1793912263990`. QEMU pid unchanged |
| 20:58:30 | 22:58:30 | `LOAD|FT>FT|…|45:08|FROZEN_OBSERVED` |

Screenshots in this directory: `zepp-clock-b-ready2.png`, `zepp-clock-b-run20.png` (`00:41` RUNNING), `zepp-clock-b-paused.png` (`00:58` PAUSED), `zepp-clock-b-resumed.png` (`01:03` RUNNING), `zepp-clock-b-returned.png` (`01:10` after leaving and returning), `zepp-clock-b-half.png` (`01:11` HALF-TIME), `zepp-clock-b-2h.png` (`45:00`), `zepp-clock-b-2h6.png` (`45:07`), `zepp-clock-b-full.png` (`45:08` FULL TIME), `zepp-clock-restored.png` (same `45:08` after recreation), `zepp-clock-apps-cdp.png`.

Console extracts: `zepp-clock-console-early.txt`, `zepp-clock-console-pass2.txt`, `console-visible.txt`.

The storage-probe marker was still present before this app replaced the loaded project (`sequence 5`, check `3cbd5c8b`). This clock did not delete probe files.

## Recovery limit

A frozen pause, half-time, or full time is restored from the two agreeing copies after a new process epoch. The simulator showed that for full time.

A running clock is not continued as an exact elapsed time across a new epoch. The last accepted sample is kept, the open gap is dropped, and the screen shows TIME UNVERIFIED until the referee chooses CONTINUE FROM LAST, which lands in pause at that last sample and does not invent the gap. That path is covered by `test/match_clock.test.js`. It was not the state under the Apps-list recreate, because that recreate happened at full time.

Ticks are not written. A process death during play therefore cannot recover seconds that were only on screen after the last whistle or pause.

## Tests

Watch client, from `apps/forref_watch_zepp`:

```text
npm test
geometry assertions passed
node --test test/match_clock.test.js
12 tests, 12 passed, 0 failed
```

Repository cloud suite from the repository root:

- `./tool/verify_cloud.sh` exited 1 before any test. `tool/cloud_bootstrap.sh` is git mode `100644`, so the direct execution was `Permission denied`. The script continued and the package suites still ran.
- `bash tool/cloud_bootstrap.sh` completed. Dart 3.13.2 and Flutter 3.47.2 matched the pin.
- `packages/forref_match_core`: analyze clean, `+377` all tests passed.
- `packages/forref_match_persistence`: analyze clean, `+92` all tests passed.
- `apps/referee_phone`: analyze clean, `+125` all tests passed.

The wrapper's exit 1 is the missing executable bit on the bootstrap script in this checkout. It is not a failing match-core, persistence, or phone test.

## Classification

| Claim | Status |
| --- | --- |
| Functional watch stopwatch in Simulator 2.1.2 | Shown for kick-off, running digits, pause, resume, half-time, 2nd half, and full time |
| Trustworthy temporal admission | Not certified. Digits are `OBSERVED_UNVERIFIED` UTC deltas |
| Durable Match Memory D1 | Not claimed. Read-back of a prototype file is not D1 |
| Hardware field certification | Not claimed. Guest is Active Max inside the simulator while Zeus selected Active 3 Premium |

LOCAL GATE REQUIRED: a physical Zepp device, power-loss, a documented monotonic clock, and a certified local D1 commit. This simulator session does not pass those gates.

## Known limits

- `createSysTimer` produced no ticks. The page uses `createTimer`, which stops when the live page is destroyed.
- A same-process return within 120 seconds adds the UTC gap as observed, unverified playing time. A larger gap or a new epoch does not.
- The 120-second same-session ceiling is a prototype guard, not a Laws of the Game rule.
- Score is `SCORE UNAVAILABLE`. Goal, card, and substitution pages were not extended.
- No phone or network call is required for these buttons. None was added.
