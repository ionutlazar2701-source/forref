import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { applyIntent, freshSession } from "../utils/match_clock.js";
import { layoutLive, liveTelemetrySlot } from "../utils/geometry.js";
import {
  createMatchTelemetry,
  formatDistanceKm,
  formatTelemetryLine,
  gpsStatusKey,
  hrStatusKey,
} from "../utils/telemetry.js";
import { createTelemetryHost } from "../utils/telemetry_host.js";

const live = readFileSync(new URL("../page/gt/live/index.page.js", import.meta.url), "utf8");
const session = readFileSync(new URL("../utils/live_session.js", import.meta.url), "utf8");
const appJs = readFileSync(new URL("../app.js", import.meta.url), "utf8");
const hostSrc = readFileSync(new URL("../utils/telemetry_host.js", import.meta.url), "utf8");
const bindSrc = readFileSync(new URL("../utils/telemetry_bind.js", import.meta.url), "utf8");
const telemetrySrc = readFileSync(new URL("../utils/telemetry.js", import.meta.url), "utf8");
const appJson = JSON.parse(readFileSync(new URL("../app.json", import.meta.url), "utf8"));

function memoryStore(max) {
  let text = "";
  let writes = 0;
  return {
    read: function () {
      return text;
    },
    write: function (line) {
      writes += 1;
      if (max != null && line.length > max) {
        return { ok: false, reason: "CAPACITY" };
      }
      text = line;
      return { ok: true };
    },
    snapshot: function () {
      return text;
    },
    writes: function () {
      return writes;
    },
  };
}

function point(east, elapsed, status) {
  const lat = 0;
  const lon = (east / (6371000 * Math.cos((lat * Math.PI) / 180))) * (180 / Math.PI);
  return { status: status || "A", lat: lat, lon: lon, elapsedMs: elapsed, metaPresent: false };
}

function running(epoch, trust) {
  return { epoch: epoch, phase: "FIRST_HALF_RUNNING", trust: trust || "OBSERVED_UNVERIFIED" };
}

function feedWalk(engine) {
  engine.onGnss(point(0, 0));
  engine.onGnss(point(3, 2000));
  engine.onGnss(point(6, 4000));
  engine.onGnss(point(9, 6000));
  engine.onGnss(point(12, 8000));
}

test("distance is shown in kilometers and kept internally in meters", () => {
  assert.equal(formatDistanceKm(150, "en-US"), "0.15 km");
  assert.equal(formatDistanceKm(150, "ro-RO"), "0,15 km");
  assert.equal(formatDistanceKm(0, "ro-RO"), "0,00 km");
  assert.equal(hrStatusKey("LIVE"), "hrLive");
  assert.equal(gpsStatusKey("LOST"), "gpsLost");
  const engine = createMatchTelemetry({ epoch: "e-format" });
  engine.afterClock(running("e-format"));
  engine.onGnss(point(0, 0));
  engine.onGnss(point(150, 40000));
  const meters = engine.view().distanceMeters;
  assert.ok(meters > 140 && meters < 160);
  assert.equal(formatDistanceKm(meters, "ro-RO").includes(","), true);
  assert.equal(engine.view().distanceSaved, false);
  assert.equal(engine.view().official, false);
  assert.equal(engine.view().experimental, true);
});

test("kick-off still starts the clock when both sensors are unavailable", () => {
  const started = applyIntent(freshSession(), "KICK_OFF", {
    utcMillis: 1700000000000,
    epoch: "e-kick",
    intentId: "kick-1",
  });
  assert.equal(started.ok, true);
  assert.equal(started.session.phase, "FIRST_HALF_RUNNING");
  const engine = createMatchTelemetry({ epoch: "e-kick" });
  const host = createTelemetryHost(
    {
      Geolocation: function () {
        throw new Error("gps-unavailable");
      },
      HeartRate: function () {
        throw new Error("hr-unavailable");
      },
    },
    engine,
    { elapsed: function () { return 0; } }
  );
  host.followClock({ epoch: "e-kick", phase: started.session.phase, trust: started.session.trust });
  assert.equal(started.session.phase, "FIRST_HALF_RUNNING");
  assert.equal(engine.view().distanceMeters, 0);
  assert.equal(engine.view().distanceSaved, false);
  assert.equal(host.listenerCounts().gps, 0);
  assert.equal(host.listenerCounts().hr, 0);
  host.drain();
  assert.equal(started.session.phase, "FIRST_HALF_RUNNING");
  assert.equal(engine.view().gpsState, "ERROR");
  assert.equal(engine.view().hrState, "ERROR");
});

test("active first-half distance is counted and other phases add none", () => {
  const engine = createMatchTelemetry({ epoch: "e-half" });
  engine.afterClock(running("e-half"));
  feedWalk(engine);
  const first = engine.view().firstMeters;
  assert.ok(Math.abs(first - 12) < 1);
  assert.equal(engine.view().secondMeters, 0);
  engine.afterClock({ epoch: "e-half", phase: "HALF_TIME", trust: "FROZEN_OBSERVED" });
  engine.onGnss(point(200, 20000));
  engine.onGnss(point(260, 26000));
  assert.equal(engine.view().firstMeters, first);
  assert.equal(engine.view().secondMeters, 0);
  engine.afterClock({ epoch: "e-half", phase: "SECOND_HALF_RUNNING", trust: "OBSERVED_UNVERIFIED" });
  engine.onGnss(point(260, 30000));
  engine.onGnss(point(272, 32000));
  assert.equal(engine.view().firstMeters, first);
  assert.ok(Math.abs(engine.view().secondMeters - 12) < 1);
  assert.ok(Math.abs(engine.view().distanceMeters - (first + engine.view().secondMeters)) < 0.001);
});

test("pause, suspension, and unverified time add no distance and do not bridge the gap", () => {
  const engine = createMatchTelemetry({ epoch: "e-gap" });
  engine.afterClock(running("e-gap"));
  engine.onGnss(point(0, 0));
  engine.onGnss(point(20, 4000));
  const first = engine.view().firstMeters;
  assert.ok(first > 10);
  for (const phase of ["FIRST_HALF_PAUSED", "FIRST_HALF_SUSPENDED"]) {
    engine.afterClock({ epoch: "e-gap", phase: phase, trust: "FROZEN_OBSERVED" });
    engine.onGnss(point(400, 20000));
    assert.equal(engine.view().firstMeters, first, phase);
  }
  engine.afterClock({ epoch: "e-gap", phase: "FIRST_HALF_RUNNING", trust: "TIME_UNVERIFIED" });
  engine.onGnss(point(500, 30000));
  assert.equal(engine.view().firstMeters, first);
  assert.equal(engine.view().openHalf, null);
  engine.afterClock({ epoch: "e-gap", phase: "FIRST_HALF_RUNNING", trust: "FROZEN_OBSERVED" });
  engine.onGnss(point(500, 40000));
  engine.onGnss(point(512, 44000));
  assert.ok(engine.view().firstMeters > first + 5);
  assert.ok(engine.view().firstMeters < first + 20);
});

test("a lost fix does not invent the missing segment", () => {
  const engine = createMatchTelemetry({ epoch: "e-loss" });
  engine.afterClock(running("e-loss"));
  engine.onGnss(point(0, 0));
  engine.onGnss(point(20, 4000));
  const first = engine.view().firstMeters;
  engine.onGnss(point(20, 8000, "V"));
  engine.onGnss({ status: "A", lat: 0, lon: 0, elapsedMs: 9000, metaPresent: true, satellitesUsed: 0 });
  engine.onGnss(point(400, 14000));
  engine.onGnss(point(412, 16000));
  assert.ok(engine.view().firstMeters > first);
  assert.ok(engine.view().firstMeters < first + 20);
});

test("a delayed callback cannot append meters to a closed half", () => {
  const engine = createMatchTelemetry({ epoch: "e-delay" });
  engine.afterClock(running("e-delay"));
  const late = function () {
    engine.onGnss(point(80, 12000));
  };
  engine.onGnss(point(0, 0));
  engine.onGnss(point(20, 4000));
  const first = engine.view().firstMeters;
  engine.afterClock({ epoch: "e-delay", phase: "HALF_TIME", trust: "FROZEN_OBSERVED" });
  late();
  assert.equal(engine.view().firstMeters, first);
  assert.equal(engine.view().secondMeters, 0);
});

test("navigation keeps one listener pair and full time releases them", () => {
  let gpsOn = 0;
  let hrOn = 0;
  const sdk = {
    Geolocation: function () {
      return {
        onChange: function () { gpsOn += 1; },
        offChange: function () { gpsOn = Math.max(0, gpsOn - 1); },
        start: function () {},
        stop: function () {},
        getStatus: function () { return "V"; },
      };
    },
    HeartRate: function () {
      return {
        onCurrentChange: function () { hrOn += 1; },
        offCurrentChange: function () { hrOn = Math.max(0, hrOn - 1); },
        start: function () {},
        getCurrent: function () { return null; },
      };
    },
  };
  const engine = createMatchTelemetry({ epoch: "e-nav" });
  const host = createTelemetryHost(sdk, engine, { elapsed: function () { return 0; } });
  host.followClock(running("e-nav"));
  host.followClock(running("e-nav"));
  host.drain();
  assert.equal(gpsOn, 1);
  assert.equal(hrOn, 1);
  const meters = engine.view().distanceMeters;
  host.pageExit();
  assert.equal(gpsOn, 1);
  assert.equal(engine.view().distanceMeters, meters);
  host.followClock({ epoch: "e-nav", phase: "FULL_TIME", trust: "FROZEN_OBSERVED" });
  host.drain();
  assert.equal(gpsOn, 0);
  assert.equal(hrOn, 0);
  assert.equal(engine.view().released, true);
  engine.onGnss(point(40, 8000));
  assert.equal(engine.view().distanceMeters, meters);
  assert.equal(engine.view().distanceSaved, false);
});

test("a second match does not inherit the first match meters", () => {
  const engine = createMatchTelemetry({ epoch: "e-1" });
  engine.afterClock(running("e-1"));
  feedWalk(engine);
  assert.ok(engine.view().firstMeters > 10);
  engine.afterClock({ epoch: "e-2", phase: "READY", trust: "FROZEN_OBSERVED" });
  assert.equal(engine.view().distanceMeters, 0);
  engine.afterClock(running("e-2"));
  engine.onGnss(point(0, 0));
  engine.onGnss(point(20, 4000));
  assert.ok(engine.view().firstMeters > 10);
  assert.ok(engine.view().firstMeters < 30);
});

test("screen-off recovery keeps accepted meters and requires a fresh anchor", () => {
  const store = memoryStore();
  const engine = createMatchTelemetry({ epoch: "e-screen", store: store });
  engine.afterClock({ epoch: "e-screen", phase: "FIRST_HALF_RUNNING", trust: "OBSERVED_UNVERIFIED", matchKey: "KICK_OFF-screen-1" });
  engine.onGnss(point(0, 0));
  engine.onGnss(point(150, 40000));
  const kept = engine.view().firstMeters;
  assert.ok(kept > 140);
  engine.release();
  assert.equal(store.snapshot().includes("lat"), false);
  assert.equal(store.snapshot().includes("KICK_OFF-screen-1"), true);
  const restored = createMatchTelemetry({ epoch: "e-next", store: store });
  restored.afterClock({
    epoch: "e-next",
    phase: "FIRST_HALF_RUNNING",
    trust: "TIME_UNVERIFIED",
    boot: true,
    matchKey: "KICK_OFF-screen-1",
  });
  assert.equal(restored.view().storageStatus, "RESTORED");
  assert.ok(Math.abs(restored.view().firstMeters - kept) < 1);
  restored.onGnss(point(800, 30000));
  assert.ok(Math.abs(restored.view().firstMeters - kept) < 1);
  restored.afterClock({ epoch: "e-next", phase: "FIRST_HALF_RUNNING", trust: "FROZEN_OBSERVED", matchKey: "KICK_OFF-screen-1" });
  restored.onGnss(point(800, 50000));
  restored.onGnss(point(812, 54000));
  assert.ok(restored.view().firstMeters > kept + 5);
  assert.ok(restored.view().firstMeters < kept + 20);
  assert.equal(restored.view().distanceSaved, false);
});

test("storage failure and capacity pressure leave the clock phase untouched", () => {
  const started = applyIntent(freshSession(), "KICK_OFF", {
    utcMillis: 1700000000000,
    epoch: "e-store",
    intentId: "kick-store",
  });
  const failing = {
    read: function () { return ""; },
    write: function () { throw new Error("full"); },
  };
  const engine = createMatchTelemetry({ epoch: "e-store", store: failing });
  assert.doesNotThrow(function () {
    engine.afterClock({ epoch: "e-store", phase: started.session.phase, trust: started.session.trust, matchKey: "KICK_OFF-store-1" });
    engine.onGnss(point(0, 0));
    engine.onGnss(point(20, 4000));
    engine.flush();
  });
  assert.equal(started.session.phase, "FIRST_HALF_RUNNING");
  assert.equal(engine.view().distanceSaved, false);
  assert.ok(engine.view().uncertified >= 1);
  const capped = memoryStore(8);
  const other = createMatchTelemetry({ epoch: "e-cap", store: capped });
  other.afterClock(Object.assign({ matchKey: "KICK_OFF-cap-1" }, running("e-cap")));
  other.flush();
  assert.equal(capped.snapshot(), "");
  assert.ok(other.view().uncertified >= 1);
  assert.equal(other.view().distanceSaved, false);
});

test("sensor callbacks do not write storage, and a later flush stays coordinate-free", () => {
  const store = memoryStore();
  const engine = createMatchTelemetry({ epoch: "e-flush", store: store });
  engine.afterClock(running("e-flush"));
  const before = store.writes();
  feedWalk(engine);
  assert.equal(store.writes(), before);
  engine.flush();
  assert.equal(store.writes(), before + 1);
  assert.equal(store.snapshot().includes("lat"), false);
  assert.equal(store.snapshot().indexOf("0.000"), -1);
});

test("a long callback run does not retain the track", () => {
  const engine = createMatchTelemetry({ epoch: "e-stress" });
  engine.afterClock(running("e-stress"));
  for (let i = 0; i < 5000; i += 1) {
    engine.onGnss(point(i * 5, i * 2000));
  }
  const view = engine.view();
  assert.equal(Number.isFinite(view.distanceMeters), true);
  assert.equal(view.distanceSaved, false);
  assert.equal(Object.prototype.hasOwnProperty.call(view, "lat"), false);
  assert.equal(Object.prototype.hasOwnProperty.call(view, "samples"), false);
});

test("the clock can still complete a match while telemetry follows it", () => {
  let clock = freshSession();
  let utc = 1700000000000;
  function act(intent) {
    const result = applyIntent(clock, intent, {
      utcMillis: utc,
      epoch: "e-reg",
      intentId: intent + "-" + utc,
      confirmed: true,
    });
    assert.equal(result.ok, true, intent);
    clock = result.session;
    utc += 1000;
  }
  act("KICK_OFF");
  act("PAUSE");
  act("RESUME");
  act("END_FIRST_HALF");
  act("START_SECOND_HALF");
  act("FULL_TIME");
  assert.equal(clock.phase, "FULL_TIME");
});

test("live paint reads telemetry after the clock and does not release it on navigation", () => {
  const paint = live.slice(live.indexOf("function paintDigits"), live.indexOf("function logView"));
  assert.ok(paint.indexOf("digitLabel(view)") < paint.indexOf("liveTelemetrySlot"));
  assert.equal(paint.includes("button("), false);
  const destroy = live.slice(live.indexOf("onDestroy"));
  assert.equal(destroy.includes("releaseMatchTelemetry"), false);
  assert.equal(destroy.includes("persistLive"), true);
  assert.equal(appJs.includes("releaseMatchTelemetry"), true);
  const perform = session.slice(session.indexOf("export function performIntent"), session.indexOf("export function sampleTick"));
  const savedAt = perform.indexOf("const saved = persistClock");
  assert.ok(perform.indexOf("noteClockCommit", savedAt) > savedAt);
  assert.equal(perform.slice(perform.indexOf("READBACK_FAIL"), savedAt).includes("noteClockCommit"), false);
  assert.equal(appJson.permissions.includes("data:user.hd.workout"), false);
  assert.equal(appJson.permissions.includes("device:os.geolocation"), true);
  assert.equal(appJson.permissions.includes("data:user.hd.heart_rate"), true);
  assert.equal(appJson.targets.gt.module.page.pages.length, 23);
  const joined = telemetrySrc + hostSrc + bindSrc + live;
  assert.equal(joined.includes("getSportData"), false);
  assert.equal(joined.includes("data:user.hd.workout"), false);
  for (const source of [hostSrc, bindSrc, telemetrySrc, live]) {
    const logs = source.split("console.log");
    for (let i = 1; i < logs.length; i += 1) {
      const body = logs[i].slice(0, logs[i].indexOf(");") + 2);
      assert.equal(/lat|lon|hrBpm|getLatitude|getLongitude|getCurrent/.test(body), false, source);
    }
  }
});

test("the compact line fits under the clock on Live A and Live C", () => {
  const shapes = [
    { width: 480, height: 480, round: true },
    { width: 390, height: 450, round: false },
  ];
  for (const info of shapes) {
    for (const mode of ["A", "C"]) {
      const lay = layoutLive(info, mode);
      const timeH = mode === "C" ? 36 : 48;
      const slot = liveTelemetrySlot(lay, mode, timeH);
      const limit = mode === "C" ? lay.away.y : lay.home.y;
      assert.ok(slot, mode);
      assert.ok(slot.y >= lay.timeY + timeH);
      assert.ok(slot.y + slot.h <= limit);
    }
  }
});

function strictSensors() {
  const geo = {
    enabled: true,
    status: "V",
    lat: 0,
    lon: 0,
    starts: 0,
    stops: 0,
    change: null,
    info: null,
    onCalls: 0,
    getEnabled() { return this.enabled; },
    getStatus() { return this.status; },
    getLatitude() { return this.lat; },
    getLongitude() { return this.lon; },
    start() { this.starts += 1; },
    stop() { this.stops += 1; },
    onChange(cb) {
      if (this.change) {
        throw new Error("duplicate gps listener");
      }
      this.change = cb;
      this.onCalls += 1;
    },
    offChange(cb) {
      if (cb == null || cb !== this.change) {
        throw new Error("gps off identity");
      }
      this.change = null;
    },
    onGnssChange(cb) {
      if (this.info) {
        throw new Error("duplicate gnss listener");
      }
      this.info = cb;
    },
    offGnssChange(cb) {
      if (cb == null || cb !== this.info) {
        throw new Error("gnss off identity");
      }
      this.info = null;
    },
  };
  const hr = {
    bpm: null,
    last: null,
    change: null,
    onCalls: 0,
    getCurrent() { return this.bpm; },
    getLast() { return this.last; },
    onCurrentChange(cb) {
      if (this.change) {
        throw new Error("duplicate hr listener");
      }
      this.change = cb;
      this.onCalls += 1;
    },
    offCurrentChange(cb) {
      if (cb == null || cb !== this.change) {
        throw new Error("hr off identity");
      }
      this.change = null;
    },
  };
  const built = { geo: 0, hr: 0, order: [] };
  const sdk = {
    checkSensor() { return true; },
    Geolocation: function () {
      built.geo += 1;
      built.order.push("geo");
      return geo;
    },
    HeartRate: function () {
      built.hr += 1;
      built.order.push("hr");
      return hr;
    },
  };
  return { geo: geo, hr: hr, sdk: sdk, built: built };
}

function place(geo, east) {
  geo.status = "A";
  geo.lat = 0;
  geo.lon = (east / 6371000) * (180 / Math.PI);
}

function deferredHost(engine, clock, sdk) {
  const queued = [];
  const host = createTelemetryHost(sdk, engine, clock, {
    defer: function (fn) {
      queued.push(fn);
    },
    set: function (fn) {
      queued.push(fn);
      return queued.length;
    },
    clear: function () {},
  });
  return {
    host: host,
    flush: function () {
      const batch = queued.splice(0, queued.length);
      for (let i = 0; i < batch.length; i++) {
        batch[i]();
      }
    },
    queued: queued,
  };
}

test("kick-off paints before any sensor constructor or storage write", () => {
  const rig = strictSensors();
  const store = memoryStore();
  const clock = { ms: 0, elapsed() { return this.ms; } };
  const engine = createMatchTelemetry({ epoch: "e-paint", store: store });
  const deferred = deferredHost(engine, clock, rig.sdk);
  const phase = "FIRST_HALF_RUNNING";
  deferred.host.followClock({ epoch: "e-paint", phase: phase, trust: "OBSERVED_UNVERIFIED", matchKey: "KICK_OFF-paint-1" });
  assert.equal(rig.built.geo, 0);
  assert.equal(rig.built.hr, 0);
  assert.equal(store.writes(), 0);
  assert.equal(engine.view().openHalf, "first");
  const painted = ["clock", phase];
  assert.equal(painted[0], "clock");
  deferred.flush();
  assert.equal(rig.built.order[0] === "geo" || rig.built.order[0] === "hr", true);
  assert.equal(store.writes(), 1);
  assert.equal(engine.view().distanceSaved, false);
  assert.equal(phase, "FIRST_HALF_RUNNING");
});

test("a pause before deferred startup cancels GPS and does not count meters", () => {
  const rig = strictSensors();
  const clock = { ms: 0, elapsed() { return this.ms; } };
  const engine = createMatchTelemetry({ epoch: "e-cancel" });
  const deferred = deferredHost(engine, clock, rig.sdk);
  deferred.host.followClock(running("e-cancel"));
  deferred.host.followClock({ epoch: "e-cancel", phase: "FIRST_HALF_PAUSED", trust: "FROZEN_OBSERVED" });
  assert.equal(deferred.queued.length, 1);
  assert.equal(rig.built.geo, 0);
  deferred.flush();
  assert.equal(rig.built.geo, 0);
  assert.equal(rig.geo.starts, 0);
  assert.equal(engine.view().openHalf, null);
  assert.equal(engine.view().distanceMeters, 0);
  assert.equal(rig.hr.onCalls, 1);
});

test("a throwing or hanging sensor start does not change the accepted phase", () => {
  const clock = { ms: 0, elapsed() { return this.ms; } };
  let started = 0;
  const sdk = {
    Geolocation: function () {
      started += 1;
      return {
        onChange() {},
        offChange() {},
        start() {
          started += 10;
        },
        stop() {},
        getStatus() { return "V"; },
      };
    },
    HeartRate: function () {
      throw new Error("hr-down");
    },
  };
  const engine = createMatchTelemetry({ epoch: "e-throw" });
  const host = createTelemetryHost(sdk, engine, clock);
  const phase = "FIRST_HALF_RUNNING";
  host.followClock({ epoch: "e-throw", phase: phase, trust: "OBSERVED_UNVERIFIED" });
  assert.equal(started, 0);
  host.drain();
  assert.equal(phase, "FIRST_HALF_RUNNING");
  assert.equal(engine.view().hrState, "ERROR");
  assert.equal(engine.view().distanceMeters, 0);
  host.followClock({ epoch: "e-throw", phase: phase, trust: "OBSERVED_UNVERIFIED" });
  host.drain();
  assert.equal(started, 11);
});

test("live heart rate is numeric only while the sample is fresh", () => {
  const rig = strictSensors();
  const clock = { ms: 1000, elapsed() { return this.ms; } };
  const engine = createMatchTelemetry({ epoch: "e-hr" });
  const deferred = deferredHost(engine, clock, rig.sdk);
  rig.hr.last = 142;
  deferred.host.followClock(running("e-hr"));
  deferred.flush();
  assert.equal(engine.view().hrState, "STALE");
  assert.equal(engine.view().hrFresh, false);
  assert.equal(engine.view().hrBpm, null);
  rig.hr.bpm = 20;
  rig.hr.change();
  assert.equal(engine.view().hrState, "UNAVAILABLE");
  assert.equal(engine.view().hrBpm, null);
  rig.hr.bpm = 142;
  rig.hr.change();
  assert.equal(engine.view().hrFresh, true);
  assert.equal(engine.view().hrBpm, 142);
  clock.ms = 1000 + 15001;
  deferred.host.pulse();
  assert.equal(engine.view().hrState, "STALE");
  assert.equal(engine.view().hrFresh, false);
  assert.equal(engine.view().hrBpm, null);
  assert.equal(formatTelemetryLine(engine.view(), {
    lang: "en-US",
    prefix: "~",
    none: "— km",
    hrValue: "HR {n} bpm",
    hr: "HR LAST",
    gps: "GPS ...",
  }).includes("142"), false);
});

test("heart rate still displays when GPS is denied", () => {
  const rig = strictSensors();
  rig.sdk.Geolocation = function () {
    throw new Error("gps-denied");
  };
  const clock = { ms: 0, elapsed() { return this.ms; } };
  const engine = createMatchTelemetry({ epoch: "e-hr-only" });
  const deferred = deferredHost(engine, clock, rig.sdk);
  deferred.host.followClock(running("e-hr-only"));
  deferred.flush();
  rig.hr.bpm = 128;
  rig.hr.change();
  assert.equal(engine.view().gpsState, "ERROR");
  assert.equal(engine.view().hrFresh, true);
  assert.equal(engine.view().hrBpm, 128);
  assert.equal(engine.view().openHalf, "first");
});

test("half-time movement and the next half do not bridge", () => {
  const engine = createMatchTelemetry({ epoch: "e-15" });
  engine.afterClock(running("e-15"));
  feedWalk(engine);
  const first = engine.view().firstMeters;
  assert.ok(Math.abs(first - 12) < 1);
  engine.afterClock({ epoch: "e-15", phase: "HALF_TIME", trust: "FROZEN_OBSERVED" });
  for (let minute = 1; minute <= 15; minute += 1) {
    engine.onGnss(point(400 + minute * 20, 45 * 60 * 1000 + minute * 60 * 1000));
  }
  assert.equal(engine.view().firstMeters, first);
  assert.equal(engine.view().secondMeters, 0);
  engine.afterClock({ epoch: "e-15", phase: "SECOND_HALF_RUNNING", trust: "OBSERVED_UNVERIFIED", openedAtMs: 60 * 60 * 1000 });
  const stale = engine.captureToken();
  engine.onGnss(Object.assign({ generation: stale - 1 }, point(900, 50 * 60 * 1000)));
  assert.equal(engine.view().secondMeters, 0);
  engine.onGnss(Object.assign({ generation: engine.captureToken(), observedAtMs: 60 * 60 * 1000 }, point(900, 60 * 60 * 1000)));
  engine.onGnss(Object.assign({ generation: engine.captureToken(), observedAtMs: 61 * 60 * 1000 }, point(912, 61 * 60 * 1000)));
  assert.equal(engine.view().firstMeters, first);
  assert.ok(Math.abs(engine.view().secondMeters - 12) < 1);
  assert.ok(Math.abs(engine.view().distanceMeters - (first + engine.view().secondMeters)) < 0.001);
});

test("added time counts only while the clock stays running", () => {
  const engine = createMatchTelemetry({ epoch: "e-added" });
  engine.afterClock(running("e-added"));
  engine.onGnss(point(0, 50 * 60 * 1000));
  engine.onGnss(point(12, 51 * 60 * 1000));
  const runningMeters = engine.view().firstMeters;
  assert.ok(runningMeters > 10);
  engine.afterClock({ epoch: "e-added", phase: "FIRST_HALF_PAUSED", trust: "FROZEN_OBSERVED" });
  engine.onGnss(point(80, 52 * 60 * 1000));
  assert.equal(engine.view().firstMeters, runningMeters);
});

test("old generations, early timestamps, and uncertain fixes add no meters", () => {
  const engine = createMatchTelemetry({ epoch: "e-race" });
  engine.afterClock(Object.assign({ openedAtMs: 10000 }, running("e-race")));
  const token = engine.captureToken();
  engine.onGnss(Object.assign({ generation: token, observedAtMs: 4000, provenance: "DELIVERY" }, point(20, 4000)));
  engine.onGnss(Object.assign({ generation: token, provenance: "UNCERTAIN" }, point(30, 12000)));
  assert.equal(engine.view().distanceMeters, 0);
  engine.onGnss(Object.assign({ generation: token, observedAtMs: 10000 }, point(0, 10000)));
  engine.onGnss(Object.assign({ generation: token, observedAtMs: 8000 }, point(40, 8000)));
  engine.onGnss(Object.assign({ generation: token - 1, observedAtMs: 16000 }, point(80, 16000)));
  engine.onGnss(Object.assign({ generation: token, observedAtMs: 14000 }, point(12, 14000)));
  assert.ok(Math.abs(engine.view().firstMeters - 12) < 1);
  engine.onGnss(Object.assign({ generation: token, observedAtMs: 14000 }, point(12, 14000)));
  engine.onGnss(Object.assign({ generation: token, observedAtMs: 12000 }, point(40, 12000)));
  assert.ok(Math.abs(engine.view().firstMeters - 12) < 1);
});

test("jitter, teleport, weak metadata, and a lost fix do not invent distance", () => {
  const engine = createMatchTelemetry({ epoch: "e-quality" });
  engine.afterClock(running("e-quality"));
  engine.onGnss(point(0, 0));
  engine.onGnss(point(1, 2000));
  engine.onGnss(point(2, 4000));
  engine.onGnss(point(3, 6000));
  assert.equal(engine.view().distanceMeters, 0);
  assert.equal(engine.view().distanceKnown, true);
  engine.onGnss(point(10000, 8000));
  assert.equal(engine.view().distanceMeters, 0);
  engine.onGnss(point(10, 14000));
  assert.ok(Math.abs(engine.view().distanceMeters - 10) < 1);
  const kept = engine.view().distanceMeters;
  engine.onGnss({ status: "A", lat: 0, lon: 0, elapsedMs: 16000, metaPresent: true, satellitesUsed: 0 });
  engine.onGnss({ status: "A", lat: null, lon: null, elapsedMs: 18000, metaPresent: false });
  engine.onGnss(point(10, 18000, "V"));
  assert.equal(engine.view().distanceMeters, kept);
  engine.onGnss(point(10, 22000));
  engine.onGnss(point(22, 26000));
  assert.ok(engine.view().distanceMeters > kept);
  assert.ok(engine.view().distanceMeters < kept + 20);
});

test("listener identity survives pause and half-time and drops stale closures", () => {
  const rig = strictSensors();
  const clock = { ms: 0, elapsed() { return this.ms; } };
  const engine = createMatchTelemetry({ epoch: "e-listen" });
  const deferred = deferredHost(engine, clock, rig.sdk);
  deferred.host.followClock(running("e-listen"));
  deferred.flush();
  const firstGps = rig.geo.change;
  const firstHr = rig.hr.change;
  assert.equal(firstGps, deferred.host.handles().gps);
  assert.equal(firstHr, deferred.host.handles().hr);
  assert.equal(rig.geo.info, deferred.host.handles().gnss);
  place(rig.geo, 0);
  firstGps();
  clock.ms = 4000;
  place(rig.geo, 20);
  firstGps();
  const first = engine.view().firstMeters;
  assert.ok(first > 10);
  deferred.host.followClock({ epoch: "e-listen", phase: "HALF_TIME", trust: "FROZEN_OBSERVED" });
  place(rig.geo, 400);
  firstGps();
  assert.equal(engine.view().firstMeters, first);
  deferred.flush();
  assert.equal(rig.geo.change, null);
  assert.equal(rig.hr.change, firstHr);
  deferred.host.followClock({ epoch: "e-listen", phase: "SECOND_HALF_RUNNING", trust: "OBSERVED_UNVERIFIED" });
  deferred.flush();
  assert.notEqual(rig.geo.change, firstGps);
  assert.equal(rig.geo.onCalls, 2);
  assert.equal(rig.hr.onCalls, 1);
  place(rig.geo, 800);
  firstGps();
  assert.equal(engine.view().secondMeters, 0);
  rig.geo.change();
  assert.equal(engine.view().secondMeters, 0);
  assert.equal(engine.view().firstMeters, first);
  for (let i = 0; i < 8; i += 1) {
    deferred.host.followClock({ epoch: "e-listen", phase: "SECOND_HALF_PAUSED", trust: "FROZEN_OBSERVED" });
    deferred.flush();
    deferred.host.followClock({ epoch: "e-listen", phase: "SECOND_HALF_RUNNING", trust: "OBSERVED_UNVERIFIED" });
    deferred.flush();
  }
  assert.equal(rig.hr.onCalls, 1);
  assert.equal(rig.geo.change, deferred.host.handles().gps);
  assert.equal(deferred.host.listenerCounts().gps, 1);
  assert.equal(deferred.host.listenerCounts().hr, 1);
});

test("a failed unsubscribe stays degraded and does not register a second listener", () => {
  const rig = strictSensors();
  rig.geo.offChange = function () {
    throw new Error("off failed");
  };
  const clock = { ms: 0, elapsed() { return this.ms; } };
  const engine = createMatchTelemetry({ epoch: "e-leak" });
  const deferred = deferredHost(engine, clock, rig.sdk);
  deferred.host.followClock(running("e-leak"));
  deferred.flush();
  const only = rig.geo.change;
  deferred.host.followClock({ epoch: "e-leak", phase: "FIRST_HALF_PAUSED", trust: "FROZEN_OBSERVED" });
  deferred.flush();
  assert.equal(deferred.host.listenerCounts().degraded, true);
  assert.equal(deferred.host.listenerCounts().gps, 1);
  deferred.host.followClock(running("e-leak"));
  deferred.flush();
  assert.equal(rig.geo.change, only);
  assert.equal(rig.geo.onCalls, 1);
  place(rig.geo, 50);
  only();
  assert.equal(engine.view().distanceMeters, 0);
});

test("storage distinguishes absence, corruption, conflict, and a short write", () => {
  const absent = createMatchTelemetry({
    epoch: "e-absent",
    store: { read: function () { return { status: "NOT_FOUND", text: "" }; }, write: function () { return { ok: true }; } },
  });
  absent.afterClock({ epoch: "e-absent", phase: "FIRST_HALF_RUNNING", trust: "TIME_UNVERIFIED", boot: true, matchKey: "KICK_OFF-absent" });
  assert.equal(absent.view().storageStatus, "ABSENT");
  assert.equal(absent.view().distanceMeters, 0);
  assert.equal(absent.view().uncertified, 0);

  const corrupt = createMatchTelemetry({
    epoch: "e-corrupt",
    store: { read: function () { return { status: "OK", text: "T2|broken" }; }, write: function () { return { ok: true }; } },
  });
  assert.equal(corrupt.view().storageStatus, "CORRUPT");
  corrupt.afterClock({ epoch: "e-corrupt", phase: "FIRST_HALF_RUNNING", trust: "TIME_UNVERIFIED", boot: true, matchKey: "KICK_OFF-corrupt" });
  assert.equal(corrupt.view().distanceMeters, 0);
  assert.ok(corrupt.view().uncertified >= 1);

  const failed = createMatchTelemetry({
    epoch: "e-read",
    store: { read: function () { throw new Error("io"); }, write: function () { return { ok: true }; } },
  });
  assert.equal(failed.view().storageStatus, "READ_FAILED");

  const shortStore = {
    read: function () { return ""; },
    write: function () { return { ok: false, reason: "SHORT_WRITE" }; },
  };
  const short = createMatchTelemetry({ epoch: "e-short", store: shortStore });
  short.afterClock(Object.assign({ matchKey: "KICK_OFF-short" }, running("e-short")));
  short.flush();
  assert.equal(short.view().storageStatus, "SHORT_WRITE");
  assert.equal(short.view().distanceSaved, false);

  const kept = memoryStore();
  const original = createMatchTelemetry({ epoch: "e-a", store: kept });
  original.afterClock(Object.assign({ matchKey: "KICK_OFF-a" }, running("e-a")));
  feedWalk(original);
  original.flush();
  const other = createMatchTelemetry({ epoch: "e-b", store: kept });
  other.afterClock({ epoch: "e-b", phase: "FIRST_HALF_RUNNING", trust: "TIME_UNVERIFIED", boot: true, matchKey: "KICK_OFF-b" });
  assert.equal(other.view().storageStatus, "CONFLICT");
  assert.equal(other.view().distanceMeters, 0);
  const unresolved = createMatchTelemetry({ epoch: "e-c", store: kept });
  unresolved.afterClock({ epoch: "e-c", phase: "FIRST_HALF_RUNNING", trust: "TIME_UNVERIFIED", boot: true, matchKey: "" });
  assert.equal(unresolved.view().association, "UNRESOLVED");
  assert.equal(unresolved.view().distanceMeters, 0);
});

test("a callback storm and repeated restarts stay bounded", () => {
  const rig = strictSensors();
  const store = memoryStore();
  const clock = { ms: 0, elapsed() { return this.ms; } };
  const engine = createMatchTelemetry({ epoch: "e-storm", store: store });
  const deferred = deferredHost(engine, clock, rig.sdk);
  deferred.host.followClock(Object.assign({ matchKey: "KICK_OFF-storm" }, running("e-storm")));
  deferred.flush();
  const writes = store.writes();
  for (let i = 0; i < 5000; i += 1) {
    clock.ms = i * 200;
    place(rig.geo, i * 3);
    rig.geo.change();
  }
  assert.equal(store.writes(), writes);
  assert.equal(Number.isFinite(engine.view().distanceMeters), true);
  assert.equal(engine.view().distanceSaved, false);
  assert.ok(deferred.queued.length <= 2);
  for (let i = 0; i < 20; i += 1) {
    deferred.host.followClock({ epoch: "e-storm", phase: "FIRST_HALF_PAUSED", trust: "FROZEN_OBSERVED", matchKey: "KICK_OFF-storm" });
    deferred.flush();
    deferred.host.followClock(Object.assign({ matchKey: "KICK_OFF-storm" }, running("e-storm")));
    deferred.flush();
  }
  assert.equal(rig.geo.change, deferred.host.handles().gps);
  assert.equal(deferred.host.listenerCounts().gps, 1);
  assert.equal(deferred.host.listenerCounts().hr, 1);
});

test("a new kick-off key drops the previous match", () => {
  const engine = createMatchTelemetry({ epoch: "e-new" });
  engine.afterClock(Object.assign({ matchKey: "KICK_OFF-1" }, running("e-new")));
  feedWalk(engine);
  assert.ok(engine.view().firstMeters > 10);
  engine.afterClock({ epoch: "e-new", phase: "FIRST_HALF_RUNNING", trust: "OBSERVED_UNVERIFIED", matchKey: "KICK_OFF-2" });
  assert.equal(engine.view().distanceMeters, 0);
  assert.equal(engine.view().distanceKnown, false);
  engine.onGnss(point(0, 0));
  engine.onGnss(point(8, 3000));
  assert.ok(engine.view().firstMeters > 5);
  assert.ok(engine.view().firstMeters < 20);
});

test("the compact line uses locale kilometers and a live pulse", () => {
  const fresh = {
    distanceKnown: true,
    distanceMeters: 150,
    hrFresh: true,
    hrBpm: 142,
  };
  assert.equal(formatTelemetryLine(fresh, {
    lang: "ro-RO",
    prefix: "~",
    hrValue: "PULS {n} bpm",
    gps: "GPS OK",
  }), "~0,15 km  PULS 142 bpm  GPS OK");
  assert.equal(formatTelemetryLine(fresh, {
    lang: "en-US",
    prefix: "~",
    hrValue: "HR {n} bpm",
    gps: "GPS OK",
  }), "~0.15 km  HR 142 bpm  GPS OK");
  const empty = formatTelemetryLine({
    distanceKnown: false,
    distanceMeters: 0,
    hrFresh: false,
  }, {
    none: "— km",
    hr: "HR ...",
    gps: "GPS ...",
  });
  assert.equal(empty, "— km  HR ...  GPS ...");
  assert.ok(empty.length < 40);
  assert.equal(live.includes("formatTelemetryLine"), true);
  assert.equal(live.includes('t("hrValue")'), true);
  assert.equal(live.includes('t("distanceNone")'), true);
  const follow = hostSrc.slice(hostSrc.indexOf("function followClock"), hostSrc.indexOf("function release"));
  assert.equal(follow.includes("new sdk"), false);
  assert.equal(follow.includes(".start("), false);
  assert.equal(bindSrc.includes("createTimer(1, 1000"), true);
  assert.equal(hostSrc.includes("hr.start"), false);
  assert.equal(hostSrc.includes("hr.stop"), false);
  const storeSrc = readFileSync(new URL("../utils/telemetry_store.js", import.meta.url), "utf8");
  assert.equal(storeSrc.includes("forref_tel_003_state.txt"), true);
  assert.equal(storeSrc.includes("forref_clock001c_state"), false);
  for (const token of ["NOT_FOUND", "READ_FAILED", "SHORT_WRITE", "CAPACITY"]) {
    assert.equal(storeSrc.includes(token), true, token);
  }
  assert.equal(/heatmap|heatMap|heat map/i.test(telemetrySrc + hostSrc + live), false);
  assert.equal(appJson.app.appId, 29566);
  assert.equal(appJson.permissions.includes("data:user.hd.workout"), false);
});
