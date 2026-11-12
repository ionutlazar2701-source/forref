# FORREF ZEPP LIVE MATCH FLOW 002

Branch: `cursor/zepp-live-match-flow-002-30fd`, based on `947a2dd467f6fc5bd437775cfa24538c453f85ba`.

## What changed

Live Match again uses `layoutLive` for A (HOME/AWAY side by side) and C (HOME, clock, AWAY). The existing `match_clock` session is the only clock. Kick Off, Pause, and Resume stay on that Live screen. Match Controls is a new route for End 1st Half, Suspend Game, Full Time, and a two-step Abandon. Formal suspension phases are `FIRST_HALF_SUSPENDED` and `SECOND_HALF_SUSPENDED`. Abandon requires `confirmed: true` and ends in `ABANDONED`, which is not Full Time and not completed.

No Match Core, persistence, or phone capture files were edited. The prototype store is still a dual-copy readback, not D1. `Time.getTime()` stays an unverified wall clock. `createTimer` only refreshes the display.

`tool/cloud_bootstrap.sh` and `tool/verify_cloud.sh` were mode `100644`, so `./tool/verify_cloud.sh` could not start. Their tracked mode is now executable. No script body changed.

## Simulator

Zepp OS Simulator **2.1.2** was downloaded from the official Linux amd64 package and started with `--no-sandbox` on `DISPLAY=:1`. Zeus CLI on this machine is **1.10.0** (the earlier clock session used 1.9.3). The shell window title is Huami OS Simulator and the corner reads v2.1.2.

The watch guest did not start. The emulator cache is empty, and the simulator presents an account login before the firmware download:

```
Account
Login
Forgot password?
No account？Sign Up
Login with Challenge
Get a Response in the Zepp App to sign in
```

The Apps page also says the watch emulator has not been downloaded. No QEMU guest, no Amazfit Active Max, and no Active 3 Premium profile were observed. `FORREF_LIVE002_BOOT` was not emitted because the new package was not loaded. KVM permissions were not changed. `/dev/kvm` remains `root:103` and this user is not in that group.

Screenshot: `docs/forref-execution/evidence/zepp-live-match-flow-002/simulator-shell-v212.png`. Login text: `simulator-login.txt`.

VISUAL SIMULATOR GATE: BLOCKED. No Live A or Live C screenshot of the new UI exists. Older clock-only screenshots are not evidence for this build.

## Node tests

Command: `npm test` in `apps/forref_watch_zepp`.

Exit code: 0.

`node test/geometry.test.js` printed `FORREF_GEOMETRY_TEST pass`. `node --test` reported 19 passed, 0 failed (12 existing clock tests, 4 new suspension/abandon tests, 3 live-surface tests).

## Canonical cloud

Command: `./tool/verify_cloud.sh` from the repository root.

Exit code: 0. Log line: `verify_cloud: PASSED — all cloud-capable suites succeeded.`

| Step | Result |
| --- | --- |
| cloud bootstrap | PASS (Flutter 3.47.2, Dart 3.13.2) |
| analyze `packages/forref_match_core` | No issues found |
| test `packages/forref_match_core` | 377 passed |
| analyze `packages/forref_match_persistence` | No issues found |
| test `packages/forref_match_persistence` | 92 passed |
| analyze `apps/referee_phone` | No issues found |
| test `apps/referee_phone` | 125 passed |

## T01–T26

| ID | Verdict | Evidence |
| --- | --- | --- |
| T01 | PARTIAL | Reducer keeps READY at 00:00. No simulator screenshot. |
| T02 | PARTIAL | Kick Off stays in the reducer and the live page does not navigate away. Not clicked on a guest. |
| T03 | PASS | Duplicate kickoff test. |
| T04 | PARTIAL | Pause freeze is unit-tested. No 15s simulator hold. |
| T05 | PARTIAL | Resume unit test. No simulator. |
| T06 | PARTIAL | Event page does not touch the session. No return-to-live capture. |
| T07 | PARTIAL | Live shows SCORE UNAVAILABLE. Event title uses DEMO — NOT RECORDED. No screenshot. |
| T08 | PASS | Injected clock: 45:00 stays running; `45 + 02:15` renders. |
| T09 | PARTIAL | End 1st Half unit test. No simulator. |
| T10 | PARTIAL | Half-time break does not add playing time in the reducer. No simulator. |
| T11 | PARTIAL | 1H 47:15 then 2H display 45:00 in the reducer. No simulator launch. |
| T12 | PARTIAL | 2H pause/resume unit test. A/C is the same session in source. No simulator. |
| T13 | PASS | Injected clock: 90:00 stays running; `90 + 03:24` renders. |
| T14 | PARTIAL | Full Time freezes and is not a completed status in the reducer. No simulator. |
| T15 | PARTIAL | Suspend from running excludes the gap in the reducer. No simulator. |
| T16 | PARTIAL | Suspend from paused adds no second segment. No simulator. |
| T17 | PARTIAL | Unconfirmed abandon is refused; confirmed abandon is ABANDONED, not FULL TIME. No simulator. |
| T18 | PARTIAL | Illegal and duplicate intents rejected in unit tests. No device log. |
| T19 | PASS | Backward jump, forward gap, and missing sample fail closed in unit tests. |
| T20 | PARTIAL | Live `onDestroy` stops only the UI timer. No lifecycle capture. |
| T21 | PARTIAL | Running reload is TIME UNVERIFIED; CONTINUE FROM LAST lands paused. No process recreate on a guest. |
| T22 | PARTIAL | Frozen pause and second-half suspension restore when both copies agree. No guest recreate. |
| T23 | PASS | Corrupt, divergent, and missing copies fail closed in unit tests. |
| T24 | PARTIAL | Geometry tests pass for round 480 and rect 390×450 A and C. No new UI capture. |
| T25 | PARTIAL | New labels exist in EN and RO. Live source has no `67:12` or `1-0`. No on-device locale pass. |
| T26 | PASS | `npm test` exit 0 (19/19 plus geometry). `./tool/verify_cloud.sh` exit 0. Match Core 377 tests, persistence 92, phone 125. Analyze clean on all three. |

## Limits

Official match time is not certified. Local D1 is not certified. Hardware, power loss, and battery are not certified. UNDO FULL TIME remains unimplemented (HUMAN GATE PENDING). The watch prototype does not write Match Records.

TRUE BLACK THEME 001 is not started. The functional screenshots this theme needs do not exist, and the accent candidates still need Founder review before any native recolor.

## Next single blocker

Zepp account login in Simulator 2.1.2, so the watch emulator can be downloaded and this branch can be loaded with `zeus dev`.
