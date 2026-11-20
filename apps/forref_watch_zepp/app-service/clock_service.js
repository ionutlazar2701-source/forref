// Background UTC observations while the Live page timer is stopped.
// createSysTimer is a scheduler. Time.getTime() is UTC, not a monotonic clock.
// reload stays false so a reboot does not resume the sampler across the gap.

import { Time } from "@zos/sensor";
import { createSysTimer, stopTimer } from "@zos/timer";
import { exit } from "@zos/app-service";
import { getSettings } from "@zos/display";
import { deviceAdapter } from "../utils/clock_device";
import { runServiceTick } from "../utils/clock_service_core";
import { screenLabel } from "../utils/clock_service_policy.js";

const clock = new Time();
let timer = null;
let memory = null;
let ticks = 0;

function nowUtc() {
  try {
    const value = clock.getTime();
    if (typeof value !== "number" || !isFinite(value)) {
      return null;
    }
    return value < 1e11 ? Math.round(value * 1000) : Math.round(value);
  } catch (err) {
    return null;
  }
}

function shutdown() {
  if (timer != null) {
    try {
      stopTimer(timer);
    } catch (err) {
      console.log("FORREF_CLOCK_SLEEP timer-stop=fail");
    }
    timer = null;
  }
  try {
    exit();
  } catch (err) {
    console.log("FORREF_CLOCK_SLEEP exit=fail");
  }
}

function screenNow() {
  try {
    return screenLabel(getSettings());
  } catch (err) {
    return "unavailable";
  }
}

function tick() {
  const result = runServiceTick(deviceAdapter(), nowUtc(), "granted", memory);
  memory = result.session;
  ticks += 1;
  const last = memory && memory.lastUtc ? memory.lastUtc : 0;
  console.log(
    "FORREF_CLOCK_SLEEP tick=" +
      ticks +
      " reason=" +
      result.reason +
      " wrote=" +
      result.wrote +
      " readback=" +
      (result.readback || "") +
      " last=" +
      last +
      " screen=" +
      screenNow()
  );
  if (result.stop) {
    shutdown();
  }
}

AppService({
  onInit() {
    console.log("FORREF_CLOCK_SLEEP service=on monotonic=none src=utc reload=false");
    try {
      if (clock.onPhoneTimeSetting) {
        clock.onPhoneTimeSetting(function () {
          console.log("FORREF_CLOCK_SLEEP phone-time-setting");
        });
      }
    } catch (err) {
      console.log("FORREF_CLOCK_SLEEP phone-time=unavailable");
    }
    try {
      timer = createSysTimer(true, 1000, tick);
      console.log("FORREF_CLOCK_SLEEP timer=" + (timer == null ? "null" : "on") + " screen=" + screenNow());
    } catch (err) {
      console.log("FORREF_CLOCK_SLEEP timer=unavailable");
    }
  },
  onDestroy() {
    if (timer != null) {
      try {
        stopTimer(timer);
      } catch (err) {
        console.log("FORREF_CLOCK_SLEEP timer-stop=fail");
      }
      timer = null;
    }
    console.log("FORREF_CLOCK_SLEEP service=off");
  },
});
