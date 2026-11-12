# Live Match Flow 002 — baseline

Baseline commit: `947a2dd467f6fc5bd437775cfa24538c453f85ba` on `cursor/zepp-match-clock-001-30fd` (PR #43). Parent live composition: `bc7a67d45a3a2f8bb54d29f81859d3e01e63904e`.

## What PR #43 removed

`page/gt/live/index.page.js` painted only `layoutClock`: status, digits, SCORE UNAVAILABLE, one or two phase actions, and BACK. `layoutLive` for Team Split (A) and Vertical (C) was still in `utils/geometry.js` and still tested, but the live page no longer called it. HOME, AWAY, and the A/C display preference were not on the live instrument. The fake `67:12` and `1–0` strings were already gone and stay gone.

## One session

`utils/match_clock.js` remains the only reducer. `utils/live_session.js` is the single process-local holder (`globalData.clockLive` plus the existing dual-copy prototype store). Live A and Live C are `state().display` values of that same session. Match Controls is a separate route that calls the same `performIntent`. It does not start a second timer. Page destruction stops the UI timer only.

## Referee path

READY on Live shows `00:00` and KICK OFF. The primary control stays on Live: KICK OFF, PAUSE, RESUME, START 2ND HALF, RESUME GAME, or CONTINUE FROM LAST. END 1ST HALF, SUSPEND GAME, FULL TIME, and guarded ABANDON sit on Match Controls. HOME and AWAY open the existing event flow, which shows DEMO — NOT RECORDED and does not write a sporting record. Display A/C is on Match Controls and does not create a session.

PAUSE holds the instrument. SUSPEND GAME is a separate frozen phase. ABANDON requires a second confirmed intent and lands on ABANDONED, never FULL TIME. That confirmation latch is cleared on navigation, Back, page exit, and when the phase or mode changes. 45:00 and 90:00 do not end a period. Unverified time shows dashes. Readback remains READBACK_ONLY_NOT_D1.

A running Live frame calls `liveFrame` before it creates widgets. Digits come from the last admitted sample. A step longer than 2.5 seconds is an unsampled gap: the display does not turn it into precise elapsed time, and a whistle does not fold that gap into the half. The prototype store for this build is `forref_clock001c_state`. The previous `forref_clock001b_state` copy is left in place.

True Black theme work is not in this PR. The route inventory is 23, including Match Controls. See `ROUTE_INVENTORY.md`.

## Geometry

Round 480 and rect 390×450 `layoutLive` targets stay inside the safe area for home, away, the primary control, and Match Controls. No third button was forced onto the clock row.
