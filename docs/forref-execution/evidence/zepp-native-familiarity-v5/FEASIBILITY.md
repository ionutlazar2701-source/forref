# Gesture feasibility — Native Familiarity V5

Baseline: PR #56 `235f789fb218730e6a6efafc809a2215df7a4e30`. The carousel branch does not include PR #57 or PR #58.

Zepp OS `onGesture` is available from API 2.0. This app targets API 4.0. The callback receives one direction constant. It does not receive a start point, an end point, or a movement length. `GESTURE_RIGHT` is the system Back gesture. Returning true skips that Back.

A team button and a horizontal swipe therefore cannot be separated on this API. A left slide is not used to change pages. Returning false for `GESTURE_RIGHT` while Live is showing leaves system Back intact. On Controls or Cautions, the same right slide returns to Live and is consumed so Back does not leave the match page. That is page recovery, not a forward carousel swipe.

The coordinate model in `utils/live_carousel.js` is tested and is not called from the page. The device path is the button fallback:

- Live opens at page 1.
- Match Controls is one tap to page 0.
- Cautions is the next tap, from page 0.
- Back to Live is one tap from either side page.
- The hardware Back key uses the same rule.
- The existing Controls and Cautions routes remain registered and are used only if the internal layout does not fit.

Page changes call no match intent and disarm an armed abandon confirmation. The app-lifetime foreground sampler is unchanged.
