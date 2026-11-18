import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createSensorHost } from "../lib/host.js";
import { memoryChunkAdapter } from "../lib/chunk_store.js";

function rig() {
  const geo = {
    enabled: true,
    status: "V",
    lat: 0,
    lon: 0,
    started: 0,
    stopped: 0,
    listeners: [],
    infoListeners: [],
    getEnabled() { return this.enabled; },
    getStatus() { return this.status; },
    getLatitude() { return this.lat; },
    getLongitude() { return this.lon; },
    start() { this.started += 1; },
    stop() { this.stopped += 1; },
    onChange(cb) { this.listeners.push(cb); },
    offChange(cb) { this.listeners = this.listeners.filter((item) => item !== cb); },
    onGnssChange(cb) { this.infoListeners.push(cb); },
    offGnssChange(cb) { this.infoListeners = this.infoListeners.filter((item) => item !== cb); },
    emit() { this.listeners.slice().forEach((cb) => cb()); },
  };
  const hr = {
    bpm: null,
    last: 70,
    listeners: [],
    stopped: 0,
    getCurrent() { return this.bpm; },
    getLast() { return this.last; },
    onCurrentChange(cb) { this.listeners.push(cb); },
    offCurrentChange(cb) { this.listeners = this.listeners.filter((item) => item !== cb); this.stopped += 1; },
    emit() { this.listeners.slice().forEach((cb) => cb()); },
  };
  const adapter = memoryChunkAdapter();
  const clock = { ms: 0, elapsed() { return this.ms; }, utc() { return this.ms; } };
  const pending = [];
  const host = createSensorHost({
    Geolocation: function () { return geo; },
    HeartRate: function () { return hr; },
    Battery: function () { return { getCurrent() { return 77; } }; },
    checkSensor() { return true; },
  }, adapter, clock, {
    set(fn) { pending.push(fn); return pending.length; },
    clear() {},
  });
  return { geo, hr, adapter, clock, host, pending };
}

test("boot and repeated start stop do not leave GPS running", () => {
  const lab = rig();
  assert.equal(lab.geo.started, 0);
  assert.equal(lab.host.listeners().gps, 0);
  lab.host.enableHr();
  assert.equal(lab.geo.started, 0);
  assert.equal(lab.hr.listeners.length, 1);
  lab.hr.last = 70;
  assert.equal(lab.host.view().hrLive, false);
  lab.host.startSession({ hrOnly: false });
  lab.host.startSession({ hrOnly: false });
  assert.equal(lab.geo.started, 1);
  assert.equal(lab.geo.listeners.length, 1);
  lab.host.stop();
  assert.equal(lab.geo.stopped, 1);
  assert.equal(lab.geo.listeners.length, 0);
  assert.equal(lab.hr.listeners.length, 0);
  lab.host.release();
  assert.equal(lab.host.release().already, true);
});

test("a sensor callback does not read storage and a weak fix does not stop GPS", () => {
  const lab = rig();
  const readsBefore = lab.adapter.reads;
  lab.host.startSession({ hrOnly: false });
  const readsAfterStart = lab.adapter.reads;
  lab.geo.status = "A";
  lab.geo.lat = 0;
  lab.geo.lon = 0;
  lab.clock.ms = 1000;
  for (let i = 0; i < 5000; i++) {
    lab.clock.ms = 1000 + i * 1000;
    lab.geo.lon = i * 0.00001;
    lab.geo.emit();
    lab.geo.infoListeners.forEach((cb) => cb({ nb_used_satellite: 0 }));
  }
  assert.equal(lab.adapter.reads, readsAfterStart);
  assert.equal(lab.adapter.writes, readsBefore === 0 ? 1 : lab.adapter.writes);
  assert.equal(lab.geo.stopped, 0);
  assert.equal(lab.geo.started, 1);
  assert.ok(lab.host.view().queueLength == null);
  assert.ok(lab.host.diagnostics().queueHighWater <= 32);
  assert.ok(lab.host.diagnostics().dropped > 0);
  assert.equal(lab.pending.length > 0, true);
  assert.equal(lab.adapter.files && Object.keys(lab.adapter.files).length, 0);
  lab.hr.bpm = 110;
  lab.hr.emit();
  assert.equal(lab.host.view().hrLive, true);
  assert.equal(lab.host.view().gpsAcquiring, true);
});

test("heart-rate-only recording never starts GPS and flush failure is unverified", () => {
  const lab = rig();
  lab.adapter.mode = "throw";
  const started = lab.host.startSession({ hrOnly: true });
  assert.equal(lab.geo.started, 0);
  assert.equal(lab.host.view().hrOnly, true);
  assert.equal(started.gps, "STOPPED");
  lab.hr.bpm = 100;
  lab.clock.ms = 2000;
  lab.hr.emit();
  lab.host.flush();
  assert.equal(lab.host.view().uncertified > 0, true);
  assert.equal(lab.host.diagnostics().distanceSaved, false);
  assert.equal(lab.host.view().hrState, "LIVE");
});

test("the host source has no full-journal read on the sensor path", () => {
  const text = readFileSync(new URL("../lib/host.js", import.meta.url), "utf8");
  assert.equal(text.includes("readAll"), false);
  assert.equal(text.includes("parseJournal"), false);
  assert.equal(text.includes("snapshot("), false);
  assert.equal(text.includes("analyzeTrack"), false);
});
