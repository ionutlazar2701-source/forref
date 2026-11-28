# Zepp Live display cadence

Package `29566`, version `1.0.14`. Official elapsed time is unchanged: a running verified segment is closed time plus `device UTC - openStartUtc`. `formatElapsed` floors that value to whole seconds. A paint does not add a second.

## State before this change

`page/gt/live/index.page.js` scheduled `createTimer(1000, 1000, paintAll)`. Every tick called `paintDigits`, which called `clearDigits()` and created new TEXT widgets. The match formula already followed device UTC. The visible step was how often that rebuild finished.

## Repair

The repeat period stays `1000` ms. The first wait is only the remainder of the current device-UTC second (`nextPaintDelay`). While the layout is unchanged, the existing TEXT widgets receive `setProperty` for the new digits. A layout change still rebuilds them. `prepareFrame` still admits from device UTC. `DISPLAY_CONTINUITY_MS`, segment commit, and the screen-off `createSysTimer(true, 1000, tick)` are unchanged.

## Automated result

`npm test` in `apps/forref_watch_zepp`. The cadence tests require twenty aligned paints to read `00:01` through `00:20`, and one paint at `+2000` ms to read `00:02` without changing `openStartUtc` or `firstHalfClosedMs`.

## Physical verification — LOCAL GATE REQUIRED

This cloud run cannot certify the Amazfit Bip 6.

1. In `apps/forref_watch_zepp`, install dependencies and preview or install version `1.0.14`.
2. Kick off a match and watch the live digits for 20 seconds.
3. PASS when the face advances one shown second at a time across that window, and the console line `FORREF_LIVE002 TIMER|period=1000` is present.
4. FAIL when the face still advances by two shown seconds while the device clock advances by one, or when `openStartUtc` no longer matches kick-off UTC.
5. A node-test pass is not this result.
