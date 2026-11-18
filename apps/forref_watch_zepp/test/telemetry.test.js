import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { applyIntent, freshSession } from "../utils/match_clock.js";
import { layoutLive, liveTelemetrySlot } from "../utils/geometry.js";
import {
  createMatchTelemetry,
  formatDistanceKm,
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
  assert.deepEqual(host.listenerCounts(), { gps: 0, hr: 0 });
  assert.equal(engine.view().gpsState, "ERROR");
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
  assert.equal(gpsOn, 1);
  assert.equal(hrOn, 1);
  const meters = engine.view().distanceMeters;
  host.pageExit();
  assert.equal(gpsOn, 1);
  assert.equal(engine.view().distanceMeters, meters);
  host.followClock({ epoch: "e-nav", phase: "FULL_TIME", trust: "FROZEN_OBSERVED" });
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
  engine.afterClock(running("e-screen"));
  engine.onGnss(point(0, 0));
  engine.onGnss(point(150, 40000));
  const kept = engine.view().firstMeters;
  assert.ok(kept > 140);
  engine.release();
  assert.equal(store.snapshot().includes("lat"), false);
  const restored = createMatchTelemetry({ epoch: "e-next", store: store });
  restored.afterClock({ epoch: "e-next", phase: "FIRST_HALF_RUNNING", trust: "TIME_UNVERIFIED", boot: true });
  assert.ok(Math.abs(restored.view().firstMeters - kept) < 1);
  restored.onGnss(point(800, 30000));
  assert.ok(Math.abs(restored.view().firstMeters - kept) < 1);
  restored.afterClock({ epoch: "e-next", phase: "FIRST_HALF_RUNNING", trust: "FROZEN_OBSERVED" });
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
    engine.afterClock({ epoch: "e-store", phase: started.session.phase, trust: started.session.trust });
    engine.onGnss(point(0, 0));
    engine.onGnss(point(20, 4000));
    engine.flush();
  });
  assert.equal(started.session.phase, "FIRST_HALF_RUNNING");
  assert.equal(engine.view().distanceSaved, false);
  assert.ok(engine.view().uncertified >= 1);
  const capped = memoryStore(8);
  const other = createMatchTelemetry({ epoch: "e-cap", store: capped });
  other.afterClock(running("e-cap"));
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
  const savedAt = perform.indexOf("const saved = commitSession");
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
