// App-lifetime sampler. It is not owned by Live, Event, Player, or Review.
// createTimer stops with the screen and with the app. It is not the screen-off clock.
// Live paints from this one timer. A second createTimer(1000, 1000) on the page
// can resume on the opposite phase and then update the digits every 2 s.

import { createTimer, stopTimer } from "@zos/timer";
import { deviceNow } from "./clock_device";
import { sampleFromScheduler } from "./live_session";
import { createForegroundHost, nextTimerDelay } from "./clock_cadence";

const host = createForegroundHost({
  utc: function () {
    return deviceNow();
  },
  now: function () {
    return Date.now();
  },
  sample: function (source) {
    return sampleFromScheduler(source);
  },
  delay: function () {
    return nextTimerDelay(deviceNow(), 1000);
  },
  arm: function (run, delay) {
    return createTimer(delay, 1000, run);
  },
  disarm: function (id) {
    stopTimer(id);
  },
  log: function (line) {
    console.log(line);
  },
});

export function startForegroundClock() {
  return host.start();
}

export function stopForegroundClock() {
  host.stop();
}

export function restartForegroundClock() {
  return host.restart();
}

export function bindLivePaint(fn) {
  return host.bind(fn);
}
