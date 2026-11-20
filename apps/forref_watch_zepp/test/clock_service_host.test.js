import test from "node:test";
import assert from "node:assert/strict";
import {
  DISPLAY_CONTINUITY_MS,
  Phase,
  Trust,
  applyIntent,
  commitSession,
  displayText,
  freshSession,
  liveFrame,
  present,
} from "../utils/match_clock.js";
import { commitForward, preferObserved } from "../utils/clock_continuity.js";
import { runServiceTick } from "../utils/clock_service_core.js";
import { createServiceHost, screenLabel, SERVICE_FILE } from "../utils/clock_service_policy.js";

const EPOCH = "epoch-a";
const T0 = 1_700_000_000_000;

function obs(utc, id) {
  return { utcMillis: utc, epoch: EPOCH, intentId: id };
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

function runningSession() {
  return { phase: Phase.FIRST_HALF_RUNNING, trust: Trust.OBSERVED };
}

function faithfulSdk(behavior) {
  const calls = [];
  const api = {
    calls: calls,
    queryPermission(option) {
      calls.push(["query", option]);
      return behavior.query ? behavior.query(option, api) : [2];
    },
    requestPermission(option) {
      calls.push(["request", option]);
      return behavior.request ? behavior.request(option, api) : 2;
    },
    start(option) {
      calls.push(["start", option]);
      return behavior.start ? behavior.start(option, api) : 0;
    },
    stop(option) {
      calls.push(["stop", option]);
      return behavior.stop ? behavior.stop(option, api) : 0;
    },
    getAllAppServices() {
      calls.push(["list"]);
      return behavior.list ? behavior.list() : [];
    },
  };
  return api;
}

function hostFor(behavior) {
  const logs = [];
  const api = faithfulSdk(behavior || {});
  const host = createServiceHost(api, function (line) {
    logs.push(line);
  });
  return { api: api, host: host, logs: logs };
}

function named(api, kind) {
  return api.calls.filter(function (call) {
    return call[0] === kind;
  });
}

function sleep001Ensure(sdk, state) {
  if (state.running || state.pending || state.denied) {
    return;
  }
  state.pending = true;
  sdk.queryPermission({
    permissions: ["device:os.bg_service"],
    callback: function () {
      state.pending = false;
      state.running = true;
    },
  });
}

test("the 1.0.4 permission callback never runs against a synchronous queryPermission", () => {
  const api = faithfulSdk({
    query: function () {
      return [2];
    },
  });
  const state = { running: false, pending: false, denied: false };
  sleep001Ensure(api, state);
  assert.equal(state.pending, true);
  assert.equal(state.running, false);
  assert.equal(named(api, "start").length, 0);
  assert.equal(DISPLAY_CONTINUITY_MS, 2500);
});

test("a synchronous authorized query starts the service and does not leave permission pending", () => {
  const { api, host, logs } = hostFor();
  host.sync(runningSession());
  const started = named(api, "start");
  assert.equal(started.length, 1);
  assert.equal(started[0][1].file, SERVICE_FILE);
  assert.equal(started[0][1].reload, false);
  assert.equal(typeof started[0][1].complete_func, "function");
  assert.equal(host.snapshot().running, true);
  assert.equal(host.snapshot().requestPending, false);
  assert.equal(logs.some((line) => line.indexOf("perm=2") >= 0), true);
  assert.equal(logs.some((line) => line.indexOf("start-code=0") >= 0), true);
  host.sync(runningSession());
  assert.equal(named(api, "start").length, 1);
});

test("an unauthorized query requests permission and waits for the callback array", () => {
  let callback = null;
  const { api, host, logs } = hostFor({
    query: function () {
      return [0];
    },
    request: function (option) {
      callback = option.callback;
      return 0;
    },
  });
  host.sync(runningSession());
  assert.equal(named(api, "start").length, 0);
  assert.equal(host.snapshot().requestPending, true);
  assert.equal(typeof callback, "function");
  callback([2]);
  assert.equal(named(api, "start").length, 1);
  assert.equal(host.snapshot().requestPending, false);
  assert.equal(host.snapshot().running, true);
  assert.equal(logs.some((line) => line.indexOf("request=0") >= 0), true);
  assert.equal(logs.some((line) => line.indexOf("request-cb=2") >= 0), true);
});

test("requestPermission return 2 starts immediately and return 1 does not", () => {
  const already = hostFor({
    query: function () {
      return [0];
    },
    request: function () {
      return 2;
    },
  });
  already.host.sync(runningSession());
  assert.equal(named(already.api, "start").length, 1);
  assert.equal(already.host.snapshot().requestPending, false);

  const none = hostFor({
    query: function () {
      return [0];
    },
    request: function () {
      return 1;
    },
  });
  none.host.sync(runningSession());
  none.host.sync(runningSession());
  assert.equal(named(none.api, "start").length, 0);
  assert.equal(named(none.api, "request").length, 1);
  assert.equal(none.host.snapshot().requestPending, false);
  assert.equal(none.host.snapshot().blocked, true);
});

test("an unknown permission and a thrown query do not stick pending or pretend to start", () => {
  const unknown = hostFor({
    query: function () {
      return [1];
    },
  });
  unknown.host.sync(runningSession());
  unknown.host.sync(runningSession());
  assert.equal(named(unknown.api, "start").length, 0);
  assert.equal(named(unknown.api, "request").length, 0);
  assert.equal(unknown.host.snapshot().requestPending, false);
  assert.equal(unknown.host.snapshot().blocked, true);

  let thrown = true;
  const flaky = hostFor({
    query: function () {
      if (thrown) {
        thrown = false;
        throw new Error("query failed");
      }
      return [2];
    },
  });
  flaky.host.sync(runningSession());
  assert.equal(flaky.host.snapshot().requestPending, false);
  assert.equal(named(flaky.api, "start").length, 0);
  flaky.host.sync(runningSession());
  assert.equal(named(flaky.api, "start").length, 1);
  assert.equal(flaky.host.snapshot().running, true);
});

test("stop requires file and complete_func and clears running only after confirmed success", () => {
  const threw = hostFor({
    stop: function () {
      throw new Error("stop failed");
    },
  });
  threw.host.sync(runningSession());
  assert.equal(threw.host.snapshot().running, true);
  threw.host.sync({ phase: Phase.FIRST_HALF_PAUSED, trust: Trust.FROZEN });
  const stopCall = named(threw.api, "stop")[0][1];
  assert.equal(stopCall.file, SERVICE_FILE);
  assert.equal(typeof stopCall.complete_func, "function");
  assert.equal(threw.host.snapshot().running, true);

  let callback = null;
  const refused = hostFor({
    stop: function (option) {
      callback = option.complete_func;
      return 2;
    },
  });
  refused.host.sync(runningSession());
  refused.host.sync({ phase: Phase.HALF_TIME, trust: Trust.FROZEN });
  callback({ file: SERVICE_FILE, result: false });
  assert.equal(refused.host.snapshot().running, true);
  callback({ file: SERVICE_FILE, result: true });
  assert.equal(refused.host.snapshot().running, false);

  const closed = hostFor({
    stop: function () {
      return 0;
    },
  });
  closed.host.sync(runningSession());
  closed.host.sync({ phase: Phase.FULL_TIME, trust: Trust.FROZEN });
  assert.equal(closed.host.snapshot().running, false);
  assert.equal(closed.logs.some((line) => line.indexOf("stop-code=0") >= 0), true);
});

test("a listed running service is not started again", () => {
  const { api, host } = hostFor({
    list: function () {
      return [{ file: SERVICE_FILE }];
    },
  });
  host.sync(runningSession());
  assert.equal(named(api, "start").length, 0);
  assert.equal(named(api, "query").length, 0);
  assert.equal(host.snapshot().running, true);
});

test("screen status maps only the documented on and off values", () => {
  assert.equal(screenLabel({ screen: { status: 1 } }), "on");
  assert.equal(screenLabel({ screen: { status: 2 } }), "off");
  assert.equal(screenLabel({}), "unknown");
  assert.equal(screenLabel(null), "unknown");
});

test("pause and half-time freeze a verified clock, and fail only after the chain is already unverified", () => {
  let session = kick(T0);
  const sampled = liveFrame(session, T0 + 10000, EPOCH);
  assert.equal(sampled.reason, "UNSAMPLED_GAP");
  session = kick(T0);
  const played = liveFrame(session, T0 + 1000, EPOCH);
  assert.equal(played.admitted, true);
  const paused = applyIntent(played.session, "PAUSE", obs(played.session.lastUtc, "pause"));
  assert.equal(paused.ok, true);
  assert.equal(paused.session.phase, Phase.FIRST_HALF_PAUSED);
  assert.equal(paused.session.trust, Trust.FROZEN);
  assert.equal(displayText(present(paused.session, T0 + 60000)), "00:01");
  assert.equal(paused.session.firstHalfClosedMs, 1000);

  const ended = applyIntent(played.session, "END_FIRST_HALF", obs(played.session.lastUtc, "half"));
  assert.equal(ended.ok, true);
  assert.equal(ended.session.phase, Phase.HALF_TIME);
  assert.equal(displayText(present(ended.session, T0 + 120000)), "00:01");

  const broken = liveFrame(played.session, T0 + 1000 + 30000, EPOCH);
  assert.equal(broken.reason, "UNSAMPLED_GAP");
  const latePause = applyIntent(broken.session, "PAUSE", obs(T0 + 31000, "late-pause"));
  assert.equal(latePause.ok, false);
  assert.equal(latePause.reason, "UNVERIFIED");
  assert.equal(latePause.session.firstHalfClosedMs, 1000);
  const lateHalf = applyIntent(broken.session, "END_FIRST_HALF", obs(T0 + 31000, "late-half"));
  assert.equal(lateHalf.reason, "UNVERIFIED");
});

test("a running service image cannot overwrite a committed pause or half-time", () => {
  const store = memory();
  const played = liveFrame(kick(T0), T0 + 1000, EPOCH).session;
  const paused = applyIntent(played, "PAUSE", obs(played.lastUtc, "pause")).session;
  assert.equal(commitSession(store, paused).ok, true);
  const chosen = preferObserved(played, paused, T0 + 2000);
  assert.equal(chosen.phase, Phase.FIRST_HALF_PAUSED);
  const tick = runServiceTick(store, T0 + 2000, "granted", played);
  assert.equal(tick.reason, "STOP");
  assert.equal(tick.wrote, false);
  assert.equal(tick.session.phase, Phase.FIRST_HALF_PAUSED);
  const kept = commitForward(store, played);
  assert.equal(kept.reason, "KEPT_HOLD");
  assert.equal(kept.session.phase, Phase.FIRST_HALF_PAUSED);

  const half = applyIntent(played, "END_FIRST_HALF", obs(played.lastUtc, "half")).session;
  assert.equal(commitSession(store, half).ok, true);
  const again = runServiceTick(store, T0 + 2500, "granted", played);
  assert.equal(again.stop, true);
  assert.equal(again.session.phase, Phase.HALF_TIME);
  assert.equal(again.session.firstHalfClosedMs, 1000);
});
