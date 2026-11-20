// Background UTC observations while the screen is off.
// createSysTimer is a scheduler. Time.getTime() is UTC, not a monotonic clock.
// A callback is counted before the screen is read. The count is not match time.
// reload stays false so a reboot does not resume the sampler across the gap.

import { Time } from "@zos/sensor";
import { createSysTimer, stopTimer } from "@zos/timer";
import { exit } from "@zos/app-service";
import { getSettings } from "@zos/display";
import { serviceAdapter, serviceNow } from "../utils/clock_service_store";
import { runServiceTick } from "../utils/clock_service_core";
import { pairProbe, tickClass } from "../utils/clock_sleep_evidence.js";
import {
  emptyWitness,
  formatWitness,
  mergeServiceLedger,
  noteCallback,
  noteCheckpoint,
  noteClass,
  noteDiagReadback,
  noteExperiment,
  noteExperimentTick,
  noteFault,
  noteLife,
  noteScreen,
  noteTimer,
  noteWrite,
  sameEvidence,
} from "../utils/clock_sleep_witness.js";
import { readWitness, writeWitness } from "../utils/clock_witness_device";

const clock = new Time();
let timer = null;
let experiment = null;
let memory = null;
let ticks = 0;
let lastCallbackUtc = null;
let closed = false;
let ledger = null;

function ensureLedger() {
  if (ledger) {
    return ledger;
  }
  try {
    ledger = readWitness();
  } catch (err) {
    ledger = emptyWitness();
  }
  return ledger;
}

function screenNow() {
  try {
    const settings = getSettings();
    const status = settings && settings.screen ? settings.screen.status : null;
    if (status === 1) {
      return "on";
    }
    if (status === 2) {
      return "off";
    }
    if (status == null) {
      return "unk";
    }
    return "unk:" + status;
  } catch (err) {
    return "fail";
  }
}

function flush(tag) {
  let file;
  try {
    file = readWitness();
  } catch (err) {
    ledger = noteWrite(ensureLedger(), { ok: false, readback: false });
    console.log("FORREF_CLOCK_SLEEP witness=fail tag=" + tag);
    return;
  }
  const record = mergeServiceLedger(file, ensureLedger());
  let stored = false;
  try {
    writeWitness(record);
    stored = sameEvidence(readWitness(), record);
  } catch (err) {
    stored = false;
  }
  ledger = noteWrite(record, { ok: stored, readback: stored });
  if (stored && (ledger.timerState || ledger.destroyReason || ledger.firstCallback || ledger.experimentState)) {
    ledger = noteDiagReadback(ledger);
  }
  if (!stored) {
    console.log("FORREF_CLOCK_SLEEP witness=fail tag=" + tag);
    return;
  }
  try {
    writeWitness(ledger);
  } catch (err) {
    console.log("FORREF_CLOCK_SLEEP witness=fail tag=" + tag);
    return;
  }
  console.log("FORREF_CLOCK_SLEEP witness=ok tag=" + tag + " " + formatWitness(ledger, serviceNow()));
}

function stopHandle(handle) {
  if (handle == null) {
    return;
  }
  try {
    stopTimer(handle);
  } catch (err) {
    console.log("FORREF_CLOCK_SLEEP timer-stop=fail");
  }
}

function shutdown(why) {
  if (closed) {
    return;
  }
  closed = true;
  stopHandle(timer);
  timer = null;
  stopHandle(experiment);
  experiment = null;
  ledger = noteLife(ensureLedger(), { destroy: why });
  flush("stop");
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

// Separate from the match sampler. Its count is not elapsed match time.
function experimentTick() {
  ledger = noteExperimentTick(ensureLedger());
  flush("experiment");
}

function tick() {
  const utc = serviceNow();
  const dt = lastCallbackUtc == null || utc == null ? null : utc - lastCallbackUtc;
  lastCallbackUtc = utc;
  ticks += 1;
  ledger = noteCallback(ensureLedger(), dt);
  const screen = screenNow();
  ledger = noteScreen(ledger, screen);
  const anchor = memory && memory.lastUtc != null ? memory.lastUtc : null;
  const step = utc == null || anchor == null ? "" : utc - anchor;
  const adapter = serviceAdapter();
  let result;
  try {
    result = runServiceTick(adapter, utc, "granted", memory);
  } catch (err) {
    console.log("FORREF_CLOCK_SLEEP tick=fail");
    flush("tick-fail");
    return;
  }
  memory = result.session;
  const probe = pairProbe(
    function () {
      return adapter.readFile();
    },
    function () {
      return adapter.readMirror();
    }
  );
  const label = tickClass(result, probe, dt == null ? null : dt);
  ledger = noteClass(ledger, label);
  if (probe.match && label === "CHAIN" && utc != null) {
    ledger = noteCheckpoint(ledger, utc);
  }
  ledger = noteFault(ledger, result.reason);
  flush("tick");
  const last = memory && memory.lastUtc ? memory.lastUtc : 0;
  console.log(
    "FORREF_CLOCK_SLEEP tick=" +
      ticks +
      " dt=" +
      (dt == null ? "" : dt) +
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
    ledger = noteLife(ensureLedger(), { init: true });
    flush("init");
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
      const id = timer == null || timer === false ? "" : String(timer);
      ledger = noteTimer(ensureLedger(), { state: id ? "created" : "failed", id: id });
      flush("timer");
      console.log(
        "FORREF_CLOCK_SLEEP service=on timer=" +
          (id ? "on" : "null") +
          " id=" +
          id +
          " screen=" +
          screenNow()
      );
    } catch (err) {
      ledger = noteTimer(ensureLedger(), { state: "failed", id: "" });
      flush("timer");
      console.log("FORREF_CLOCK_SLEEP service=on timer=unavailable screen=" + screenNow());
    }
    try {
      experiment = createSysTimer(true, 5000, experimentTick);
      const id = experiment == null || experiment === false ? "" : String(experiment);
      ledger = noteExperiment(ensureLedger(), { state: id ? "created" : "failed", id: id });
      flush("experiment-create");
    } catch (err) {
      ledger = noteExperiment(ensureLedger(), { state: "failed", id: "" });
      flush("experiment-create");
      console.log("FORREF_CLOCK_SLEEP experiment=unavailable");
    }
  },
  onDestroy() {
    stopHandle(timer);
    timer = null;
    stopHandle(experiment);
    experiment = null;
    if (!closed) {
      closed = true;
      ledger = noteLife(ensureLedger(), { destroy: "destroy" });
      flush("destroy");
      console.log("FORREF_CLOCK_SLEEP service=off reason=destroy screen=" + screenNow());
    }
  },
});
