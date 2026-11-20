import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  Phase,
  Trust,
  DISPLAY_CONTINUITY_MS,
  REGULATION_HALF_MS,
  freshSession,
  applyIntent,
  present,
  displayText,
  loadSession,
  commitSession,
  advance,
  admitDisplay,
  liveFrame,
} from "../utils/match_clock.js";
import { commitForward, preferObserved, projectFrame, readStoredSession } from "../utils/clock_continuity.js";
import { runServiceTick } from "../utils/clock_service_core.js";

const EPOCH = "epoch-a";
const T0 = 1_700_000_000_000;

function obs(utc, id, epoch) {
  return { utcMillis: utc, epoch: epoch || EPOCH, intentId: id };
}

function kick(at) {
  const started = applyIntent(freshSession(), "KICK_OFF", obs(at, "kick"));
  assert.equal(started.ok, true);
  return started.session;
}

function memory(seed) {
  const box = { file: seed == null ? "" : seed, kv: seed == null ? "" : seed };
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
    box: box,
  };
}

function pump(store, session, seconds) {
  let current = session;
  let utc = session.lastUtc;
  const reasons = [];
  for (let i = 0; i < seconds; i += 1) {
    utc += 1000;
    const result = runServiceTick(store, utc, "granted", current);
    reasons.push(result.reason);
    assert.equal(result.ok, true, result.reason + " at " + i);
    assert.equal(result.wrote, true);
    current = result.session;
  }
  return { session: current, utc: utc, reasons: reasons };
}

test("the continuity window stays 2.5 seconds", () => {
  assert.equal(DISPLAY_CONTINUITY_MS, 2500);
});

test("a chain of one-second observations keeps exact time across 5, 30, and 120 seconds", () => {
  for (const seconds of [5, 30, 120]) {
    const store = memory();
    const started = kick(T0);
    assert.equal(commitSession(store, started).ok, true);
    const ran = pump(store, started, seconds);
    const view = present(ran.session, ran.utc);
    assert.equal(view.trust === Trust.UNVERIFIED, false);
    assert.equal(displayText(view), seconds >= 60 ? "02:00" : "00:" + String(seconds).padStart(2, "0"));
    assert.equal(ran.session.lastUtc - ran.session.openStartUtc, seconds * 1000);
    assert.equal(ran.session.epoch, EPOCH);
    assert.equal(ran.reasons.every((reason) => reason === "TICK"), true);
  }
});

test("one paint across 5, 30, or 120 seconds without observations does not invent the gap", () => {
  for (const gap of [5000, 30000, 120000]) {
    const started = kick(T0);
    const played = admitDisplay(started, T0 + 5000, EPOCH);
    assert.equal(played.reason, "UNSAMPLED_GAP");
    const session = kick(T0);
    const frame = liveFrame(session, T0 + gap, EPOCH);
    assert.equal(frame.reason, "UNSAMPLED_GAP");
    assert.equal(frame.admitted, false);
    assert.equal(frame.session.trust, Trust.UNVERIFIED);
    assert.equal(frame.session.firstHalfClosedMs, 0);
    assert.equal(frame.view.digits, null);
    assert.equal(displayText(frame.view), null);
    assert.equal(frame.view.lastKnown, "00:00");
    assert.notEqual(frame.session.firstHalfClosedMs, gap);
  }
});

test("a fresh stored checkpoint continues a stale page, and a stale checkpoint does not", () => {
  const store = memory();
  const started = kick(T0);
  assert.equal(commitSession(store, started).ok, true);
  const ran = pump(store, started, 30);
  const stalePage = started;
  const now = ran.utc + 1000;
  const stored = readStoredSession(store);
  const frame = projectFrame(stalePage, stored, now, "epoch-relaunch");
  assert.equal(frame.admitted, true);
  assert.equal(displayText(frame.view), "00:31");
  assert.equal(frame.session.trust === Trust.UNVERIFIED, false);
  assert.equal(frame.session.epoch, "epoch-relaunch");

  const absent = projectFrame(stalePage, null, T0 + 30000, EPOCH);
  assert.equal(absent.reason, "UNSAMPLED_GAP");
  assert.equal(absent.view.digits, null);
  assert.equal(absent.session.firstHalfClosedMs, 0);

  const alsoStale = projectFrame(stalePage, started, T0 + 30000, EPOCH);
  assert.equal(alsoStale.reason, "UNSAMPLED_GAP");
  assert.equal(alsoStale.session.firstHalfClosedMs, 0);
});

test("service ticks survive a stopped page timer and a denied sampler writes nothing", () => {
  const store = memory();
  const started = kick(T0);
  assert.equal(commitSession(store, started).ok, true);
  const ran = pump(store, started, 30);
  const woken = projectFrame(started, readStoredSession(store), ran.utc + 500, EPOCH);
  assert.equal(displayText(woken.view), "00:30");

  const denied = runServiceTick(store, ran.utc + 30000, "denied", null);
  assert.equal(denied.reason, "PERMISSION_DENIED");
  assert.equal(denied.wrote, false);
  const still = readStoredSession(store);
  assert.equal(still.lastUtc, ran.utc);
  const late = liveFrame(still, ran.utc + 30000, EPOCH);
  assert.equal(late.reason, "UNSAMPLED_GAP");
  assert.equal(late.session.firstHalfClosedMs, 30000);
  assert.equal(late.view.digits, null);
});

test("reload resumes only inside the continuity window and never adds a recovery gap", () => {
  const store = memory();
  const started = kick(T0);
  const played = pump(store, started, 8).session;
  assert.equal(commitSession(store, played).ok, true);

  const near = loadSession(store, "epoch-new", played.lastUtc + 1500);
  assert.equal(near.reason, "CONTINUITY_RESUMED");
  assert.equal(near.session.epoch, "epoch-new");
  assert.equal(near.session.trust === Trust.UNVERIFIED, false);
  assert.equal(displayText(present(near.session, played.lastUtc + 1500)), "00:08");
  const stepped = admitDisplay(near.session, played.lastUtc + 1500, "epoch-new");
  assert.equal(stepped.reason, "TICK");
  assert.equal(displayText(present(stepped.session, played.lastUtc + 1500)), "00:09");
  assert.equal(near.session.firstHalfClosedMs, 0);

  const omitted = loadSession(store, "epoch-new");
  assert.equal(omitted.reason, "RECOVERY_REQUIRED");
  assert.equal(omitted.session.firstHalfClosedMs, 8000);
  assert.equal(displayText(present(omitted.session, played.lastUtc + 30000)), null);

  for (const gap of [30000, 120000]) {
    const late = loadSession(store, "epoch-reboot", played.lastUtc + gap);
    assert.equal(late.reason, "RECOVERY_REQUIRED");
    assert.equal(late.session.firstHalfClosedMs, 8000);
    assert.notEqual(late.session.firstHalfClosedMs, 8000 + gap);
    assert.equal(late.session.trust, Trust.UNVERIFIED);
  }
});

test("pause, half-time, and added time do not grow from sampler ticks", () => {
  const store = memory();
  let session = pump(store, kick(T0), 10).session;
  const paused = applyIntent(session, "PAUSE", obs(session.lastUtc, "pause"));
  assert.equal(paused.ok, true);
  assert.equal(commitSession(store, paused.session).ok, true);
  const held = runServiceTick(store, paused.session.lastUtc + 30000, "granted", null);
  assert.equal(held.stop, true);
  assert.equal(held.session.firstHalfClosedMs, 10000);
  assert.equal(displayText(present(held.session, paused.session.lastUtc + 30000)), "00:10");

  const half = applyIntent(advance(kick(T0), T0 + 12000), "END_FIRST_HALF", obs(T0 + 12000, "half"));
  assert.equal(commitSession(store, half.session).ok, true);
  const broken = runServiceTick(store, T0 + 12000 + 60000, "granted", null);
  assert.equal(broken.stop, true);
  assert.equal(broken.session.phase, Phase.HALF_TIME);
  assert.equal(broken.session.firstHalfClosedMs, 12000);

  const long = advance(kick(T0), T0 + REGULATION_HALF_MS - 2000);
  assert.equal(commitSession(store, long).ok, true);
  const added = pump(store, long, 5);
  assert.equal(added.session.phase, Phase.FIRST_HALF_RUNNING);
  assert.equal(displayText(present(added.session, added.utc)), "45 + 00:03");

  const ended = applyIntent(added.session, "END_FIRST_HALF", obs(added.utc, "half-2"));
  const second = applyIntent(ended.session, "START_SECOND_HALF", obs(added.utc + 1000, "second"));
  assert.equal(displayText(present(second.session, added.utc + 1000)), "45:00");
  assert.equal(commitSession(store, second.session).ok, true);
  const secondRan = pump(store, second.session, 4);
  assert.equal(displayText(present(secondRan.session, secondRan.utc)), "45:04");
  assert.equal(secondRan.session.phase, Phase.SECOND_HALF_RUNNING);
});

test("backward, jumped, duplicate, and out-of-order observations do not fabricate elapsed time", () => {
  const store = memory();
  const started = kick(T0);
  assert.equal(commitSession(store, started).ok, true);
  const ran = pump(store, started, 6);

  const backward = runServiceTick(store, ran.utc - 1000, "granted", ran.session);
  assert.equal(backward.ok, false);
  assert.equal(backward.reason, "BACKWARD");
  assert.equal(backward.session.trust, Trust.UNVERIFIED);
  assert.equal(backward.session.firstHalfClosedMs, 6000);

  const jumpedStore = memory();
  const base = kick(T0);
  assert.equal(commitSession(jumpedStore, base).ok, true);
  const first = runServiceTick(jumpedStore, T0 + 1000, "granted", base);
  const jumped = runServiceTick(jumpedStore, T0 + 1000 + 3000, "granted", first.session);
  assert.equal(jumped.reason, "UNSAMPLED_GAP");
  assert.equal(jumped.session.firstHalfClosedMs, 1000);
  assert.equal(jumped.view === undefined, true);
  assert.equal(present(jumped.session, T0 + 4000).digits, null);

  const duplicate = runServiceTick(jumpedStore, T0 + 1000, "granted", first.session);
  assert.equal(duplicate.reason, "HELD");
  assert.equal(duplicate.wrote, false);
  assert.equal(duplicate.session.lastUtc, T0 + 1000);

  const older = kick(T0);
  const newer = admitDisplay(older, T0 + 2000, EPOCH).session;
  const chosen = preferObserved(newer, older, T0 + 2500);
  assert.equal(chosen.lastUtc, newer.lastUtc);
  const adopted = preferObserved(older, newer, T0 + 2500);
  assert.equal(adopted.lastUtc, newer.lastUtc);
});

test("a readback failure or a file conflict does not become exact match time", () => {
  const box = { file: "", kv: "" };
  let frozen = false;
  const sticky = {
    writeFile(raw) {
      if (!frozen) {
        box.file = raw;
      }
      return true;
    },
    writeKv(raw) {
      if (!frozen) {
        box.kv = raw;
      }
      return true;
    },
    readFile() {
      return box.file;
    },
    readKv() {
      return box.kv;
    },
  };
  const started = kick(T0);
  assert.equal(commitSession(sticky, started).ok, true);
  frozen = true;
  const failed = runServiceTick(sticky, T0 + 1000, "granted", started);
  assert.equal(failed.wrote, false);
  assert.equal(readStoredSession(sticky).lastUtc, T0);
  const reloaded = loadSession(sticky, EPOCH, T0 + 30000);
  assert.equal(reloaded.reason, "RECOVERY_REQUIRED");
  assert.equal(reloaded.session.firstHalfClosedMs, 0);

  const conflicted = memory();
  assert.equal(commitSession(conflicted, started).ok, true);
  conflicted.box.kv = "other";
  assert.equal(readStoredSession(conflicted), null);
  const missed = runServiceTick(conflicted, T0 + 1000, "granted", null);
  assert.equal(missed.reason, "NO_SESSION");
  assert.equal(missed.wrote, false);
  const painted = projectFrame(null, null, T0 + 1000, EPOCH);
  assert.equal(painted.view.digits, null);
});

test("an older or unverified write does not replace a newer running checkpoint", () => {
  const store = memory();
  const started = kick(T0);
  const ran = pump(store, started, 5).session;
  const stale = admitDisplay(started, T0 + 1000, EPOCH).session;
  const kept = commitForward(store, stale);
  assert.equal(kept.reason, "KEPT_NEWER");
  assert.equal(readStoredSession(store).lastUtc, ran.lastUtc);
  const failed = liveFrame(started, T0 + 30000, EPOCH).session;
  const still = commitForward(store, failed);
  assert.equal(still.reason, "KEPT_NEWER");
  assert.equal(readStoredSession(store).trust === Trust.UNVERIFIED, false);
  assert.equal(readStoredSession(store).lastUtc, ran.lastUtc);
});

test("the sampler does not start a match and a ready session stays stopped", () => {
  const store = memory();
  assert.equal(runServiceTick(store, T0, "granted", null).reason, "NO_SESSION");
  const ready = freshSession();
  ready.epoch = EPOCH;
  assert.equal(commitSession(store, ready).ok, true);
  const stopped = runServiceTick(store, T0 + 5000, "granted", null);
  assert.equal(stopped.stop, true);
  assert.equal(stopped.session.phase, Phase.READY);
  assert.equal(stopped.session.openStartUtc, null);
  assert.equal(displayText(present(stopped.session, T0 + 5000)), "00:00");
});

test("the device wiring does not treat relaunch, a phone-time callback, or reboot reload as a clock", () => {
  const service = readFileSync(new URL("../app-service/clock_service.js", import.meta.url), "utf8");
  const bind = readFileSync(new URL("../utils/clock_service_bind.js", import.meta.url), "utf8");
  const app = readFileSync(new URL("../app.js", import.meta.url), "utf8");
  const manifest = JSON.parse(readFileSync(new URL("../app.json", import.meta.url), "utf8"));
  assert.equal(service.includes("monotonic=none"), true);
  assert.equal(service.includes("reload=false"), true);
  assert.equal(service.includes("onPhoneTimeSetting"), true);
  assert.equal(service.includes("failClosed"), false);
  assert.equal(bind.includes("reload: false"), true);
  assert.equal(bind.includes("reload: true"), false);
  assert.equal(app.includes("setWakeUpRelaunch"), true);
  assert.equal(manifest.permissions.includes("device:os.bg_service"), true);
  assert.equal(manifest.permissions.includes("data:user.hd.workout"), false);
  assert.deepEqual(manifest.targets.gt.module["app-service"].services, ["app-service/clock_service"]);
  assert.equal(manifest.app.appId, 29566);
});
