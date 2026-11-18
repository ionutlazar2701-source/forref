import test from "node:test";
import assert from "node:assert/strict";
import { QUEUE_MAX, createSession } from "../lib/session_controller.js";

function point(lat, lon, elapsedMs) {
  return { type: "sample", status: "A", lat: lat, lon: lon, elapsedMs: elapsedMs, metaPresent: false };
}

test("invalid GNSS does not block heart rate or add distance across a gap", () => {
  const session = createSession();
  session.startRecording({ hrOnly: false, sessionId: "V2-0001" });
  session.markGpsStart();
  session.onHr(128, 1000);
  session.onGps(point(0, 0, 1000));
  session.onGps(point(0.0001, 0, 6000));
  const before = session.view().distanceMeters;
  session.onGps({ type: "sample", status: "V", lat: null, lon: null, elapsedMs: 7000, metaPresent: false });
  assert.equal(session.view().hrState, "LIVE");
  assert.equal(session.view().hrLive, true);
  assert.equal(session.view().gpsState, "WEAK_OR_STALE");
  session.onGps(point(1, 0, 8000));
  assert.equal(session.view().gpsState, "RECOVERED");
  assert.equal(session.view().distanceMeters, before);
  assert.ok(session.view().gaps >= 1);
});

test("preview heart-rate samples are not queued and a saturated queue is counted", () => {
  const session = createSession();
  session.enableHr();
  session.onHr(120, 0);
  assert.equal(session.queueLength(), 0);
  session.startRecording({ hrOnly: true, sessionId: "V2-0002" });
  for (let i = 0; i < QUEUE_MAX + 10; i++) {
    session.onHr(120, i * 1000);
  }
  assert.equal(session.queueLength(), QUEUE_MAX);
  assert.equal(session.view().dropped, 10);
  assert.equal(session.view().uncertified, 10);
  const diag = session.diagnostics();
  assert.equal(Object.prototype.hasOwnProperty.call(diag, "hrBpm"), false);
  assert.equal(Object.prototype.hasOwnProperty.call(diag, "lat"), false);
  assert.equal(diag.distanceSaved, false);
});
