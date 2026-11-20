// Background UTC observations while the screen is off.
// createSysTimer is a scheduler. Time.getTime() is UTC, not a monotonic clock.
// A callback delta is evidence. It does not grant elapsed match time.
// reload stays false so a reboot does not resume the sampler across the gap.

import { Time } from "@zos/sensor";
import { createSysTimer, stopTimer } from "@zos/timer";
import { exit } from "@zos/app-service";
import { getSettings } from "@zos/display";
import { serviceAdapter, serviceNow } from "../utils/clock_service_store";
import { runServiceTick } from "../utils/clock_service_core";
import { screenLabel } from "../utils/clock_service_policy.js";
import { pairProbe, tickClass } from "../utils/clock_sleep_evidence.js";
import { formatWitness, noteServiceTick } from "../utils/clock_sleep_witness.js";
import { readWitness, writeWitness } from "../utils/clock_witness_device";

const clock = new Time();
let timer = null;
let memory = null;
let ticks = 0;
let lastCallbackUtc = null;
let closed = false;

function shutdown(why) {
  if (closed) {
    return;
  }
  closed = true;
  if (timer != null) {
    try {
      stopTimer(timer);
    } catch (err) {
      console.log("FORREF_CLOCK_SLEEP timer-stop=fail");
    }
    timer = null;
  }
  const phase = memory && memory.phase ? memory.phase : "";
  const trust = memory && memory.trust ? memory.trust : "";
  const notice = memory && memory.notice ? memory.notice : "";
  console.log(
    "FORREF_CLOCK_SLEEP service=off reason=" +
      why +
      " phase=" +
      phase +
      " trust=" +
      trust +
      " notice=" +
      notice +
      " screen=" +
      screenNow()
  );
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

function recordOffWitness(screen, dt, label, committed, utc) {
  if (screen !== "off") {
    console.log("FORREF_CLOCK_SLEEP witness=held screen=" + screen);
    return;
  }
  try {
    const noted = noteServiceTick(readWitness(), {
      screen: "off",
      dt: dt,
      class: label,
      committed: committed,
      utc: utc,
    });
    if (noted.write) {
      writeWitness(noted.witness);
      console.log("FORREF_CLOCK_SLEEP witness=" + formatWitness(noted.witness, utc));
    }
  } catch (err) {
    console.log("FORREF_CLOCK_SLEEP witness=fail");
  }
}

function tick() {
  const utc = serviceNow();
  const dt = lastCallbackUtc == null || utc == null ? "" : utc - lastCallbackUtc;
  const anchor = memory && memory.lastUtc != null ? memory.lastUtc : null;
  const step = utc == null || anchor == null ? "" : utc - anchor;
  lastCallbackUtc = utc;
  const adapter = serviceAdapter();
  const result = runServiceTick(adapter, utc, "granted", memory);
  memory = result.session;
  ticks += 1;
  const probe = pairProbe(
    function () {
      return adapter.readFile();
    },
    function () {
      return adapter.readMirror();
    }
  );
  const label = tickClass(result, probe, dt === "" ? null : dt);
  const last = memory && memory.lastUtc ? memory.lastUtc : 0;
  const screen = screenNow();
  recordOffWitness(screen, dt, label, probe.match && label === "CHAIN", utc);
  console.log(
    "FORREF_CLOCK_SLEEP tick=" +
      ticks +
      " dt=" +
      dt +
      " step=" +
      step +
      " utc=" +
      (utc == null ? "" : utc) +
      " reason=" +
      result.reason +
      " class=" +
      label +
      " wrote=" +
      result.wrote +
      " readback=" +
      (result.readback || "") +
      " file=" +
      (probe.fileOk ? "ok" : "fail") +
      " mirror=" +
      (probe.mirrorOk ? "ok" : "fail") +
      " pair=" +
      (probe.match ? "match" : "miss") +
      " last=" +
      last +
      " screen=" +
      screen
  );
  if (result.stop) {
    shutdown("stop");
  }
}

AppService({
  onInit() {
    console.log("FORREF_CLOCK_SLEEP service=init screen=" + screenNow() + " monotonic=none src=utc reload=false");
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
      console.log(
        "FORREF_CLOCK_SLEEP service=on timer=" +
          (timer == null ? "null" : "on") +
          " id=" +
          (timer == null ? "" : timer) +
          " screen=" +
          screenNow()
      );
    } catch (err) {
      console.log("FORREF_CLOCK_SLEEP service=on timer=unavailable screen=" + screenNow());
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
    if (!closed) {
      closed = true;
      console.log("FORREF_CLOCK_SLEEP service=off reason=destroy screen=" + screenNow());
    }
  },
});
