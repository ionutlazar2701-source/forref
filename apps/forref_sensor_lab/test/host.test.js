import test from "node:test";
import assert from "node:assert/strict";
import { createJournal, memoryAdapter } from "../lib/journal.js";
import { createSensorHost } from "../lib/host.js";
import { analyzeTrack } from "../lib/analytics.js";

function fakeGeo() {
  const listeners = [];
  const infoListeners = [];
  return {
    enabled: true,
    status: "V",
    lat: 0,
    lon: 0,
    started: 0,
    stopped: 0,
    getEnabled() { return this.enabled; },
    getStatus() { return this.status; },
    getLatitude() { return this.lat; },
    getLongitude() { return this.lon; },
    start() { this.started += 1; },
    stop() { this.stopped += 1; },
    onChange(cb) { listeners.push(cb); },
    offChange(cb) { const index = listeners.indexOf(cb); if (index >= 0) listeners.splice(index, 1); },
    onGnssChange(cb) { infoListeners.push(cb); },
    offGnssChange(cb) { const index = infoListeners.indexOf(cb); if (index >= 0) infoListeners.splice(index, 1); },
    emit() { listeners.slice().forEach((cb) => cb()); },
    listeners: listeners,
  };
}

function fakeHr() {
  const listeners = [];
  return {
    bpm: null,
    stopped: 0,
    getCurrent() { return this.bpm; },
    onCurrentChange(cb) { listeners.push(cb); },
    offCurrentChange(cb) { const index = listeners.indexOf(cb); if (index >= 0) listeners.splice(index, 1); this.stopped += 1; },
    emit() { listeners.slice().forEach((cb) => cb()); },
    listeners: listeners,
  };
}

function lab() {
  const geo = fakeGeo();
  const hr = fakeHr();
  let distanceListeners = [];
  const distance = {
    raw: 12,
    onChange(cb) { distanceListeners.push(cb); },
    offChange(cb) { distanceListeners = distanceListeners.filter((item) => item !== cb); },
    getCurrent() { return this.raw; },
    emit() { distanceListeners.slice().forEach((cb) => cb()); },
  };
  const clock = { ms: 0, elapsed() { return this.ms; }, utc() { return 1700000000000 + this.ms; } };
  const book = createJournal(memoryAdapter());
  const host = createSensorHost({
    Geolocation: function () { return geo; },
    HeartRate: function () { return hr; },
    Distance: function () { return distance; },
    Battery: function () { return { getCurrent() { return 80; } }; },
    display: {
      onStatusChange(cb) { this.cb = cb; },
      offStatusChange() { this.cb = null; },
    },
  }, book, clock);
  return { geo, hr, distance, clock, book, host };
}

test("permission denied and a missing fix store no coordinates and do not claim a sample success", () => {
  const rig = lab();
  rig.geo.enabled = false;
  const denied = rig.host.start();
  assert.equal(denied.ok, false);
  assert.equal(denied.reason, "PERMISSION_DENIED");
  assert.equal(rig.geo.started, 0);
  assert.equal(rig.book.read().entries.some((entry) => entry.lat != null), false);
  rig.geo.enabled = true;
  assert.equal(rig.host.start().ok, true);
  rig.geo.status = "V";
  rig.geo.lat = 44.4;
  rig.geo.lon = 26.1;
  rig.clock.ms = 1000;
  rig.geo.emit();
  const gnss = rig.book.read().entries.filter((entry) => entry.kind === "GNSS")[0];
  assert.equal(gnss.gpsStatus, "V");
  assert.equal(gnss.lat, null);
  assert.equal(gnss.lon, null);
  assert.equal(gnss.flags.indexOf("NO_FIX") >= 0, true);
});

test("continuous HR starts and tears down, and a screen-off gap is quantified", () => {
  const rig = lab();
  assert.equal(rig.host.start().ok, true);
  rig.hr.bpm = 132;
  rig.clock.ms = 1000;
  rig.hr.emit();
  rig.distance.emit();
  rig.geo.status = "A";
  rig.geo.lat = 0;
  rig.geo.lon = 0;
  rig.clock.ms = 2000;
  rig.geo.emit();
  rig.host.noteLifecycle("DISPLAY_OFF");
  rig.clock.ms = 25000;
  rig.geo.lat = 0.0001;
  rig.geo.emit();
  const report = analyzeTrack(rig.book.read().entries);
  assert.equal(report.gaps.some((gap) => gap.reason === "SCREEN_OFF_OR_PAUSE" && gap.missingMs === 23000), true);
  assert.equal(rig.hr.listeners.length, 1);
  rig.host.stop();
  assert.equal(rig.hr.listeners.length, 0);
  assert.equal(rig.hr.stopped, 1);
  assert.equal(rig.geo.stopped, 1);
  assert.equal(rig.geo.listeners.length, 0);
  assert.equal(rig.host.running(), false);
  const hr = rig.book.read().entries.find((entry) => entry.kind === "HR");
  assert.equal(hr.hrBpm, 132);
  const distance = rig.book.read().entries.find((entry) => entry.kind === "DISTANCE");
  assert.equal(distance.distanceUnit, "UNRESOLVED");
  assert.equal(report.distanceSensorUsedInGnss, false);
});

test("a restart with a reversed clock does not invent the missing interval", () => {
  const rig = lab();
  rig.host.start();
  rig.geo.status = "A";
  rig.clock.ms = 5000;
  rig.geo.emit();
  rig.clock.ms = 1000;
  rig.geo.lat = 0.01;
  rig.geo.emit();
  const gap = rig.book.read().entries.find((entry) => entry.kind === "GAP");
  assert.equal(gap.gapReason, "RESTART_UNMEASURED");
  assert.equal(gap.missingMs, null);
  const report = analyzeTrack(rig.book.read().entries);
  assert.equal(report.discarded.some((item) => item.reason === "NON_POSITIVE_TIME"), true);
});
