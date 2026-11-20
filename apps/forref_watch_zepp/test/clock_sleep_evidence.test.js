import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  DISPLAY_CONTINUITY_MS,
  Phase,
  Trust,
  applyIntent,
  displayText,
  freshSession,
  liveFrame,
  loadSession,
  present,
} from "../utils/match_clock.js";
import { readStoredSession } from "../utils/clock_continuity.js";
import { runServiceTick } from "../utils/clock_service_core.js";
import { createServiceHost } from "../utils/clock_service_policy.js";
import { classifySleep, pairProbe, startClass, tickClass } from "../utils/clock_sleep_evidence.js";

const EPOCH = "epoch-a";
const T0 = 1_700_000_000_000;
const root = new URL("../", import.meta.url);

function obs(utc, id) {
  return { utcMillis: utc, epoch: EPOCH, intentId: id };
}

function kick(at) {
  const started = applyIntent(freshSession(), "KICK_OFF", obs(at, "kick"));
  assert.equal(started.ok, true);
  return started.session;
}

function mirrorOnly() {
  const box = { file: "", mirror: "" };
  return {
    writeFile(raw) {
      box.file = raw;
      return true;
    },
    readFile() {
      return box.file;
    },
    writeMirror(raw) {
      box.mirror = raw;
      return true;
    },
    readMirror() {
      return box.mirror;
    },
    writeKv() {
      return false;
    },
    readKv() {
      return "";
    },
    box: box,
  };
}

function source(path) {
  return readFileSync(new URL(path, root), "utf8");
}

function sleepChain(seconds) {
  const store = mirrorOnly();
  let session = kick(T0);
  let utc = T0;
  const ticks = [];
  for (let i = 0; i < seconds; i += 1) {
    utc += 1000;
    const result = runServiceTick(store, utc, "granted", session);
    const probe = pairProbe(
      function () {
        return store.readFile();
      },
      function () {
        return store.readMirror();
      }
    );
    const label = tickClass(result, probe, 1000);
    ticks.push({ dt: 1000, class: label, reason: result.reason });
    assert.equal(result.wrote, true, result.reason);
    assert.equal(label, "CHAIN");
    assert.equal(probe.match, true);
    session = result.session;
  }
  const restored = loadSession(store, EPOCH, utc + 1000);
  return { session: session, utc: utc, ticks: ticks, restored: restored };
}

test("the continuity window stays 2.5 seconds", () => {
  assert.equal(DISPLAY_CONTINUITY_MS, 2500);
});

test("screen-off chains of 5, 30, and 120 seconds read back and resume inside the window", () => {
  for (const seconds of [5, 30, 120]) {
    const ran = sleepChain(seconds);
    const face = displayText(present(ran.session, ran.session.lastUtc));
    const minutes = Math.floor(seconds / 60);
    const remain = seconds % 60;
    assert.equal(face, String(minutes).padStart(2, "0") + ":" + String(remain).padStart(2, "0"));
    assert.equal(ran.restored.reason, "CONTINUITY_RESUMED");
    assert.equal(
      classifySleep({
        serviceOn: true,
        timerOn: true,
        offTicks: ran.ticks,
        wakeReason: ran.restored.reason,
      }),
      "CHAIN"
    );
  }
});

test("a callback wider than 2.5 seconds is a timer gap and adds no elapsed time", () => {
  for (const seconds of [5, 30, 120]) {
    const started = kick(T0);
    const frame = liveFrame(started, T0 + seconds * 1000, EPOCH);
    const label = tickClass({ reason: frame.reason, wrote: false }, { match: false }, seconds * 1000);
    assert.equal(frame.reason, "UNSAMPLED_GAP");
    assert.equal(label, "TIMER_GAP");
    assert.equal(frame.session.firstHalfClosedMs, 0);
    assert.equal(frame.view.digits, null);
    assert.equal(
      classifySleep({
        serviceOn: true,
        timerOn: true,
        offTicks: [{ dt: seconds * 1000, class: label }],
        wakeReason: "RECOVERY_REQUIRED",
      }),
      "TIMER_GAP"
    );
  }
});

test("a tick that cannot read back the file pair is a persistence failure", () => {
  const store = mirrorOnly();
  store.writeMirror = function () {
    throw new Error("mirror");
  };
  const started = kick(T0);
  const result = runServiceTick(store, T0 + 1000, "granted", started);
  const probe = pairProbe(
    function () {
      return store.readFile();
    },
    function () {
      return store.readMirror();
    }
  );
  assert.equal(result.reason, "TICK");
  assert.equal(result.wrote, false);
  assert.equal(tickClass(result, probe, 1000), "PERSIST");
  assert.equal(readStoredSession(store), null);
  assert.equal(started.firstHalfClosedMs, 0);
  assert.equal(
    classifySleep({
      serviceOn: true,
      timerOn: true,
      offTicks: [{ dt: 1000, class: "PERSIST" }],
      wakeReason: "CONFLICT",
    }),
    "PERSIST"
  );
});

test("wake reasons stay distinct from a missing service and a silent timer", () => {
  assert.equal(classifySleep({}), "SERVICE");
  assert.equal(classifySleep({ serviceOn: true, timerOn: false, offTicks: [] }), "TIMER_CREATE");
  assert.equal(classifySleep({ serviceOn: true, timerOn: true, offTicks: [] }), "TIMER_SILENT");
  assert.equal(
    classifySleep({
      serviceOn: true,
      timerOn: true,
      offTicks: [{ dt: 1000, class: "CHAIN" }],
      wakeReason: "RECOVERY_REQUIRED",
    }),
    "RECOVERY"
  );
  assert.equal(
    classifySleep({
      serviceOn: true,
      timerOn: true,
      offTicks: [{ dt: 1000, class: "CHAIN" }],
      wakeReason: "UNSAMPLED_GAP",
    }),
    "RECOVERY"
  );
  assert.equal(
    classifySleep({
      serviceOn: true,
      timerOn: true,
      offTicks: [{ dt: 1000, class: "CHAIN" }],
      wakeReason: "CONFLICT",
    }),
    "RECOVERY"
  );
  assert.equal(startClass(0), "ok");
  assert.equal(startClass(3), "permission");
  assert.equal(startClass(7), "limit");
});

test("a same-utc callback is held and does not write", () => {
  const store = mirrorOnly();
  const started = kick(T0);
  const first = runServiceTick(store, T0 + 1000, "granted", started);
  const probe = pairProbe(
    function () {
      return store.readFile();
    },
    function () {
      return store.readMirror();
    }
  );
  assert.equal(tickClass(first, probe, 1000), "CHAIN");
  const again = runServiceTick(store, T0 + 1000, "granted", first.session);
  assert.equal(again.reason, "HELD");
  assert.equal(again.wrote, false);
  assert.equal(tickClass(again, probe, 0), "HELD");
  assert.equal(again.session.lastUtc, first.session.lastUtc);
});

test("stopping a paused clock records the phase, and an unverified clock records unverified", () => {
  const logs = [];
  const sdk = {
    queryPermission() {
      return [2];
    },
    start() {
      return 0;
    },
    stop() {
      return 0;
    },
    getAllAppServices() {
      return [];
    },
  };
  const host = createServiceHost(sdk, (line) => logs.push(line));
  host.sync({ phase: Phase.FIRST_HALF_RUNNING, trust: Trust.OBSERVED });
  host.sync({ phase: Phase.FIRST_HALF_PAUSED, trust: Trust.FROZEN });
  assert.equal(logs.some((line) => line.indexOf("stop-reason=phase") >= 0), true);
  assert.equal(logs.some((line) => line.indexOf("start-class=ok") >= 0), true);
  assert.equal(logs.some((line) => line.indexOf("host running=") >= 0), true);

  const unverified = [];
  const other = createServiceHost(sdk, (line) => unverified.push(line));
  other.sync({ phase: Phase.FIRST_HALF_RUNNING, trust: Trust.OBSERVED });
  other.sync({ phase: Phase.FIRST_HALF_RUNNING, trust: Trust.UNVERIFIED });
  assert.equal(unverified.some((line) => line.indexOf("stop-reason=unverified") >= 0), true);
});

test("the evidence lines are present and the foreground sampler is unchanged", () => {
  const service = source("app-service/clock_service.js");
  assert.equal(service.includes("dt="), true);
  assert.equal(service.includes("step="), true);
  assert.equal(service.includes("file="), true);
  assert.equal(service.includes("mirror="), true);
  assert.equal(service.includes("pair="), true);
  assert.equal(service.includes("class="), true);
  assert.equal(service.includes("reason=destroy"), true);
  assert.equal(service.includes("reason=\" +"), true);
  assert.equal(service.includes("service=init"), true);
  assert.equal(service.includes("createSysTimer"), true);
  assert.equal(service.includes("@zos/storage"), false);
  const policy = source("utils/clock_service_policy.js");
  assert.equal(policy.includes("stop-reason="), true);
  assert.equal(policy.includes("start-class="), true);
  assert.equal(policy.includes("reload: false"), true);
  const session = source("utils/live_session.js");
  assert.equal(session.indexOf("liveFrame") < session.indexOf("return frame.view"), true);
  assert.equal(session.includes("recover="), true);
  assert.equal(session.includes("edge="), true);
  const foreground = source("utils/clock_foreground_bind.js");
  assert.equal(foreground.includes("createTimer"), true);
  assert.equal(foreground.includes("sampleFromScheduler"), true);
  assert.equal(source("app.js").includes("startForegroundClock"), true);
  assert.equal(source("page/gt/event/index.page.js").includes("createTimer"), false);
});
