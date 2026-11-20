// App-lifetime sampler. It is not owned by Live, Event, Player, or Review.
// createTimer stops with the screen and with the app. It is not the screen-off clock.

import { createTimer, stopTimer } from "@zos/timer";
import { sampleFromScheduler } from "./live_session";

let timerId = null;

export function startForegroundClock() {
  if (timerId != null) {
    return;
  }
  timerId = createTimer(1000, 1000, function () {
    try {
      sampleFromScheduler("fg");
    } catch (err) {
      console.log("FORREF_CLOCK_FG src=fg reason=UNAVAILABLE");
    }
  });
  console.log("FORREF_CLOCK_FG timer=on");
}

export function stopForegroundClock() {
  if (timerId == null) {
    return;
  }
  try {
    stopTimer(timerId);
  } catch (err) {
    console.log("FORREF_CLOCK_FG timer-stop=fail");
  }
  timerId = null;
  console.log("FORREF_CLOCK_FG timer=off");
}
