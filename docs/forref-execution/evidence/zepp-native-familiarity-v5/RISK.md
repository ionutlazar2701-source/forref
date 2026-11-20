# Risks — Native Familiarity V5

- Installing this package replaces app 29566 on the watch. Do not sideload it over a CLOCK-SLEEP device build.
- `onGesture` cannot prove that a swipe missed a team button. Forward swipe stays blocked until a coordinate API is available and tested on the Bip 6.
- Right-slide Back from Controls or Cautions is consumed in code and returns to Live. That behavior is not certified on hardware.
- The 1.0.6 Live surface still shows `actions[0]`. While a half is running, that button is Pause. The V5 concept removed Pause from the primary surface. This prototype keeps the one-tap Pause so the working control is not hidden behind the carousel. Founder review can move it.
- Layout renders in `frames/` are drawn from the geometry functions. They are not Zepp simulator or Bip 6 framebuffers. The bitmap font clips long labels; the device text widget wraps.
- `layoutStack` now accepts an optional bottom limit so carousel rows stay above the dots. Callers that omit the limit keep the previous placement. Live A/C hit rectangles are unchanged.
- No new score, ledger, clock, or telemetry authority is added. Screen-off time is not claimed.
