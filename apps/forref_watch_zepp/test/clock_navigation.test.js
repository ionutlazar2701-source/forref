import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  DISPLAY_CONTINUITY_MS,
  Phase,
  Trust,
  applyIntent,
  commitDurable,
  commitSession,
  displayText,
  encodeSession,
  freshSession,
  liveFrame,
  loadSession,
  present,
} from "../utils/match_clock.js";
import { commitForward, projectFrame, readStoredSession } from "../utils/clock_continuity.js";
import { runServiceTick } from "../utils/clock_service_core.js";
import { createServiceHost, SERVICE_FILE } from "../utils/clock_service_policy.js";

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

function textOf(session) {
  return displayText(present(session, session.lastUtc));
}

function fullStore() {
  const box = { file: "", kv: "", mirror: "" };
  return {
    writeFile(raw) {
      box.file = raw;
      return true;
    },
    readFile() {
      return box.file;
    },
    writeKv(raw) {
      box.kv = raw;
      return true;
    },
    readKv() {
      return box.kv;
    },
    writeMirror(raw) {
      box.mirror = raw;
      return true;
    },
    readMirror() {
      return box.mirror;
    },
    box: box,
  };
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

function watch(store, session, seconds) {
  let current = session;
  let utc = session.lastUtc;
  for (let i = 0; i < seconds; i += 1) {
    utc += 1000;
    const frame = projectFrame(current, readStoredSession(store), utc, EPOCH);
    assert.equal(frame.admitted, true, frame.reason);
    assert.notEqual(frame.session.trust, Trust.UNVERIFIED);
    const saved = commitForward(store, frame.session);
    assert.equal(saved.ok, true, saved.reason);
    current = saved.session || frame.session;
  }
  return current;
}

function sleep(store, session, seconds) {
  let current = session;
  let utc = session.lastUtc;
  for (let i = 0; i < seconds; i += 1) {
    utc += 1000;
    const result = runServiceTick(store, utc, "granted", current);
    assert.equal(result.ok, true, result.reason);
    assert.equal(result.wrote, true);
    assert.equal(result.readback, "FILE_MIRROR");
    current = result.session;
  }
  return { session: current, utc: utc };
}

function source(path) {
  return readFileSync(new URL(path, root), "utf8");
}

test("the continuity window stays 2.5 seconds", () => {
  assert.equal(DISPLAY_CONTINUITY_MS, 2500);
});

test("twelve seconds on event, player, and review keep exact time from the shared sampler", () => {
  const store = fullStore();
  let session = kick(T0);
  assert.equal(commitSession(store, session).ok, true);
  for (const page of ["event", "player", "review"]) {
    const before = session.lastUtc - session.openStartUtc;
    session = watch(store, session, 12);
    assert.equal(session.lastUtc - session.openStartUtc, before + 12000, page);
    assert.notEqual(session.trust, Trust.UNVERIFIED, page);
  }
  assert.equal(textOf(session), "00:36");
  assert.equal(store.box.file, store.box.kv);
  assert.equal(store.box.file, store.box.mirror);
});

test("twelve seconds with no observer leaves the gap out of the match", () => {
  const started = kick(T0);
  for (const seconds of [12, 5, 30, 120]) {
    const frame = liveFrame(started, T0 + seconds * 1000, EPOCH);
    assert.equal(frame.admitted, false);
    assert.equal(frame.reason, "UNSAMPLED_GAP");
    assert.equal(frame.session.trust, Trust.UNVERIFIED);
    assert.equal(frame.session.firstHalfClosedMs, started.firstHalfClosedMs);
    assert.equal(frame.view.digits, null);
    assert.equal(displayText(frame.view), null);
  }
});

test("screen-off ticks of 5, 30, and 120 seconds persist through the file pair when local storage cannot be written", () => {
  for (const seconds of [5, 30, 120]) {
    const store = mirrorOnly();
    const started = kick(T0);
    const ran = sleep(store, started, seconds);
    const face = textOf(ran.session);
    const minutes = Math.floor(seconds / 60);
    const remain = seconds % 60;
    const expected =
      String(minutes).padStart(2, "0") + ":" + String(remain).padStart(2, "0");
    assert.equal(face, expected);
    assert.equal(store.box.file, store.box.mirror);
    assert.notEqual(store.box.file, "");
    const restored = loadSession(store, EPOCH, ran.utc + 1000);
    assert.equal(restored.reason, "CONTINUITY_RESUMED");
    assert.equal(textOf(restored.session), face);
    const again = runServiceTick(store, ran.utc, "granted", ran.session);
    assert.equal(again.reason, "HELD");
    assert.equal(again.wrote, false);
  }
});

test("a screen-off gap with no service tick is not added to the match", () => {
  const started = kick(T0);
  const store = mirrorOnly();
  assert.equal(commitDurable(store, started).reason, "FILE_MIRROR");
  for (const seconds of [5, 30, 120]) {
    const frame = liveFrame(started, T0 + seconds * 1000, EPOCH);
    assert.equal(frame.reason, "UNSAMPLED_GAP");
    assert.equal(frame.session.firstHalfClosedMs, 0);
    const restored = loadSession(store, EPOCH, T0 + seconds * 1000);
    assert.equal(restored.reason, "RECOVERY_REQUIRED");
    assert.equal(restored.session.firstHalfClosedMs, 0);
    assert.equal(displayText(present(restored.session, T0 + seconds * 1000)), null);
  }
});

test("a file and local-storage mismatch without a matching mirror stays a conflict", () => {
  const store = fullStore();
  delete store.readMirror;
  delete store.writeMirror;
  const started = kick(T0);
  store.box.file = encodeSession(started);
  store.box.kv = encodeSession(kick(T0 + 1000));
  assert.equal(loadSession(store, EPOCH, T0 + 1000).reason, "CONFLICT");
  assert.equal(readStoredSession(store), null);
});

test("a file that matches its mirror is accepted when local storage is stale", () => {
  const store = fullStore();
  const started = kick(T0);
  const raw = encodeSession(started);
  store.box.file = raw;
  store.box.mirror = raw;
  store.box.kv = encodeSession(kick(T0 + 60000));
  const restored = loadSession(store, EPOCH, T0 + 1000);
  assert.equal(restored.reason, "CONTINUITY_RESUMED");
  assert.equal(restored.session.lastUtc, T0);
  assert.equal(readStoredSession(store).lastUtc, T0);
});

test("a pause during capture freezes the elapsed time", () => {
  const store = fullStore();
  let session = kick(T0);
  assert.equal(commitSession(store, session).ok, true);
  session = watch(store, session, 10);
  assert.equal(textOf(session), "00:10");
  const paused = applyIntent(session, "PAUSE", obs(session.lastUtc + 1000, "pause"));
  assert.equal(paused.ok, true);
  assert.equal(textOf(paused.session), "00:11");
  assert.equal(commitSession(store, paused.session).ok, true);
  const later = projectFrame(paused.session, readStoredSession(store), paused.session.lastUtc + 12000, EPOCH);
  assert.equal(later.reason, "HELD");
  assert.equal(textOf(later.session), "00:11");
  assert.equal(later.session.phase, Phase.FIRST_HALF_PAUSED);
});

test("a service that disappears from the running list is started again on the next check", () => {
  const logs = [];
  const calls = [];
  const sdk = {
    queryPermission() {
      return [2];
    },
    requestPermission() {
      return 2;
    },
    start(option) {
      calls.push(option);
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
  const running = { phase: Phase.FIRST_HALF_RUNNING, trust: Trust.OBSERVED };
  host.sync(running);
  host.sync(running);
  assert.equal(calls.length, 1);
  host.sync(running);
  assert.equal(calls.length, 2);
  assert.equal(calls[1].file, SERVICE_FILE);
  assert.equal(calls[1].reload, false);
  assert.equal(logs.some((line) => line.indexOf("services=absent") >= 0), true);
  assert.equal(logs.some((line) => line.indexOf("services=restart") >= 0), true);
});

test("a thrown service list does not count as an absent service", () => {
  let fail = false;
  const calls = [];
  const sdk = {
    queryPermission() {
      return [2];
    },
    start(option) {
      calls.push(option);
      return 0;
    },
    stop() {
      return 0;
    },
    getAllAppServices() {
      if (fail) {
        throw new Error("list failed");
      }
      return [];
    },
  };
  const host = createServiceHost(sdk, () => {});
  const running = { phase: Phase.FIRST_HALF_RUNNING, trust: Trust.OBSERVED };
  host.sync(running);
  fail = true;
  host.sync(running);
  host.sync(running);
  assert.equal(calls.length, 1);
});

test("capture pages do not own a clock timer and the app sampler is separate from Live paint", () => {
  for (const page of [
    "page/gt/event/index.page.js",
    "page/gt/player/index.page.js",
    "page/gt/review/index.page.js",
  ]) {
    assert.equal(source(page).includes("createTimer"), false, page);
  }
  assert.equal(source("page/gt/player/index.page.js").includes("FORREF_LIFE player onInit"), true);
  assert.equal(source("page/gt/review/index.page.js").includes("FORREF_LIFE review onInit"), true);
  const app = source("app.js");
  assert.equal(app.includes("startForegroundClock"), true);
  assert.equal(app.includes("stopForegroundClock"), true);
  const service = source("app-service/clock_service.js");
  assert.equal(service.includes("clock_service_store"), true);
  assert.equal(service.includes("clock_device"), false);
  assert.equal(service.includes("@zos/storage"), false);
  assert.equal(service.includes("createSysTimer"), true);
  const live = source("utils/live_session.js");
  assert.equal(live.indexOf("liveFrame") < live.indexOf("return frame.view"), true);
  assert.equal(live.includes("sampleFromScheduler"), true);
});
