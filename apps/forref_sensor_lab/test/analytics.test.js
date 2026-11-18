import test from "node:test";
import assert from "node:assert/strict";
import { analyzeTrack, buildHeatMap, haversineMeters, HR_HOLD_MS, measureSegment, toLocalMeters } from "../lib/analytics.js";

function gnss(seq, elapsed, lat, lon, status) {
  return {
    kind: "GNSS",
    seq: seq,
    sessionId: "LAB-0001",
    gpsStatus: status || "A",
    lat: lat,
    lon: lon,
    diagnosticElapsedMs: elapsed,
    flags: [],
  };
}

function metersPoint(origin, east, north) {
  const lat = origin.lat + (north / 6371000) * (180 / Math.PI);
  const lon = origin.lon + (east / (6371000 * Math.cos((origin.lat * Math.PI) / 180))) * (180 / Math.PI);
  return { lat: lat, lon: lon };
}

test("invalid coordinates, no fix, duplicates, and non-positive time are discarded", () => {
  const report = analyzeTrack([
    gnss(1, 1000, 91, 0),
    gnss(2, 2000, 0, 0, "V"),
    gnss(3, 3000, 0.001, 0.001),
    gnss(4, 3000, 0.001, 0.001),
    gnss(5, 2500, 0.002, 0.001),
    gnss(6, null, 0.003, 0.001),
  ], "LAB-0001");
  assert.deepEqual(report.discarded.map((item) => item.reason), ["INVALID_COORD", "NO_FIX", "DUPLICATE", "NON_POSITIVE_TIME", "UNKNOWN_TIME"]);
  assert.equal(report.accepted.length, 1);
  assert.equal(report.distanceMeters, 0);
  assert.equal(report.certifiedDistance, false);
});

test("short walking steps accumulate from a held anchor and jitter under four meters does not", () => {
  const origin = { lat: 0, lon: 0 };
  const walked = [0, 3, 6, 9, 12].map((east, index) => {
    const point = metersPoint(origin, east, 0);
    return gnss(index + 1, index * 2000, point.lat, point.lon);
  });
  const report = analyzeTrack(walked, "LAB-0001");
  assert.ok(report.discarded.some((item) => item.reason === "STATIONARY"));
  assert.ok(Math.abs(report.distanceMeters - 12) < 1);
  const held = measureSegment(
    { lat: origin.lat, lon: origin.lon, elapsedMs: 0 },
    { lat: metersPoint(origin, 3, 0).lat, lon: metersPoint(origin, 3, 0).lon, elapsedMs: 2000 },
  );
  assert.equal(held.reason, "STATIONARY");
  assert.equal(held.moveAnchor, false);
  const jitter = [0, 1, -1, 2, 0].map((east, index) => {
    const point = metersPoint(origin, east, 0);
    return gnss(index + 1, index * 5000, point.lat, point.lon);
  });
  const still = analyzeTrack(jitter, "LAB-0001");
  assert.equal(still.distanceMeters, 0);
});

test("stationary drift does not add distance and a teleport is not a max speed", () => {
  const origin = { lat: 0, lon: 0 };
  const a = metersPoint(origin, 0, 0);
  const drift = metersPoint(origin, 1, 1);
  const jump = metersPoint(origin, 500, 0);
  const report = analyzeTrack([
    gnss(1, 0, a.lat, a.lon),
    gnss(2, 5000, drift.lat, drift.lon),
    gnss(3, 10000, jump.lat, jump.lon),
  ], "LAB-0001");
  assert.equal(report.discarded.some((item) => item.reason === "TELEPORT"), true);
  assert.equal(report.distanceMeters, 0);
  assert.equal(report.maxSpeedMps, null);
  assert.ok(haversineMeters(a, jump) > 400);
});

test("a measured gap is not interpolated, including a screen-off pause and a 10 minute trace", () => {
  const origin = { lat: 0, lon: 0 };
  const rows = [];
  let seq = 1;
  for (let second = 0; second <= 600; second += 5) {
    if (second === 300) {
      rows.push({ kind: "LIFECYCLE", name: "DISPLAY_OFF", seq: seq, sessionId: "LAB-0001", flags: [] });
      seq += 1;
      continue;
    }
    if (second === 305) {
      continue;
    }
    const point = metersPoint(origin, second * 2, 0);
    const elapsed = second === 310 ? 340000 : second * 1000;
    rows.push(gnss(seq, elapsed, point.lat, point.lon));
    seq += 1;
  }
  const report = analyzeTrack(rows, "LAB-0001");
  assert.ok(report.gaps.some((gap) => gap.reason === "SCREEN_OFF_OR_PAUSE" && gap.missingMs > 15000));
  assert.ok(report.distanceMeters > 1000);
  assert.ok(report.distanceMeters < 1300);
  assert.ok(report.maxSpeedMps < 12);
  assert.equal(report.medicalInterpretation, false);
});

test("an isolated spike is excluded from the maximum speed", () => {
  const origin = { lat: 0, lon: 0 };
  const points = [0, 10, 50, 60].map((east, index) => {
    const point = metersPoint(origin, east, 0);
    return gnss(index + 1, index * 5000, point.lat, point.lon);
  });
  const report = analyzeTrack(points, "LAB-0001");
  assert.equal(report.segments.some((segment) => segment.spike), true);
  assert.ok(report.maxSpeedMps == null || report.maxSpeedMps < 6);
});

test("heart-rate dropouts and the distance sensor stay out of the GNSS distance", () => {
  const origin = { lat: 0, lon: 0 };
  const a = metersPoint(origin, 0, 0);
  const b = metersPoint(origin, 20, 0);
  const report = analyzeTrack([
    gnss(1, 0, a.lat, a.lon),
    { kind: "HR", seq: 2, sessionId: "LAB-0001", hrBpm: 140, flags: [] },
    { kind: "HR", seq: 3, sessionId: "LAB-0001", hrBpm: null, flags: ["HR_UNAVAILABLE"] },
    { kind: "HR", seq: 4, sessionId: "LAB-0001", hrBpm: 0, flags: [] },
    { kind: "HR", seq: 5, sessionId: "LAB-0001", hrBpm: 150, flags: [] },
    { kind: "DISTANCE", seq: 6, sessionId: "LAB-0001", distanceRaw: 9999, distanceUnit: "UNRESOLVED", distanceAttribution: "UNRESOLVED", flags: ["UNIT_UNRESOLVED"] },
    gnss(7, 10000, b.lat, b.lon),
  ], "LAB-0001");
  assert.equal(report.hrSampleRatio, 0.5);
  assert.equal(report.hrTimeCoverage, 0);
  assert.equal(Object.prototype.hasOwnProperty.call(report, "hrCoverage"), false);
  assert.equal(report.hrNote, "NOT_A_HEALTH_DIAGNOSIS");
  assert.equal(report.distanceSensorUsedInGnss, false);
  assert.equal(report.distanceSensorUnit, "UNRESOLVED");
  assert.ok(Math.abs(report.distanceMeters - 20) < 1);
});

test("separate sessions are not combined and a missing session id analyzes nothing", () => {
  const origin = { lat: 0, lon: 0 };
  const mid = metersPoint(origin, 50, 0);
  const far = metersPoint(origin, 100, 0);
  const near = metersPoint(origin, 30, 0);
  const first = gnss(1, 0, origin.lat, origin.lon);
  const second = gnss(2, 10000, mid.lat, mid.lon);
  const third = gnss(3, 20000, far.lat, far.lon);
  const otherA = Object.assign({}, gnss(4, 0, origin.lat, origin.lon), { sessionId: "LAB-0002" });
  const otherB = Object.assign({}, gnss(5, 10000, near.lat, near.lon), { sessionId: "LAB-0002" });
  const rows = [first, second, third, otherA, otherB];
  const onlyFirst = analyzeTrack(rows, "LAB-0001");
  const onlySecond = analyzeTrack(rows, "LAB-0002");
  const refused = analyzeTrack(rows);
  assert.equal(onlyFirst.sessionScope, "SESSION");
  assert.ok(Math.abs(onlyFirst.distanceMeters - 100) < 1);
  assert.ok(Math.abs(onlySecond.distanceMeters - 30) < 1);
  assert.equal(refused.sessionScope, "SESSION_REQUIRED");
  assert.equal(refused.distanceMeters, 0);
  assert.equal(refused.accepted.length, 0);
});

test("a valid heart-rate sample ratio is not reported as time coverage", () => {
  const origin = { lat: 0, lon: 0 };
  const end = metersPoint(origin, 20, 0);
  const report = analyzeTrack([
    gnss(1, 0, origin.lat, origin.lon),
    { kind: "HR", seq: 2, sessionId: "LAB-0001", hrBpm: 140, diagnosticElapsedMs: 0, flags: [] },
    { kind: "HR", seq: 3, sessionId: "LAB-0001", hrBpm: 150, diagnosticElapsedMs: 5000, flags: [] },
    { kind: "HR", seq: 4, sessionId: "LAB-0002", hrBpm: 180, diagnosticElapsedMs: 1000, flags: [] },
    gnss(5, 600000, end.lat, end.lon),
  ], "LAB-0001");
  assert.equal(report.hrSampleRatio, 1);
  assert.equal(report.hrSamples, 2);
  assert.equal(report.hrTimeCoveredMs, HR_HOLD_MS);
  assert.ok(report.hrTimeCoverage < 0.02);
  assert.notEqual(report.hrTimeCoverage, report.hrSampleRatio);
});

test("a synthetic pitch heat map counts coverage and refuses a missing track or calibration", () => {
  const sw = { lat: 0, lon: 0 };
  const se = metersPoint(sw, 105, 0);
  const nw = metersPoint(sw, 0, 68);
  const inside = metersPoint(sw, 52.5, 34);
  const outside = metersPoint(sw, 500, 0);
  const map = buildHeatMap([inside, outside], { sw: sw, se: se, nw: nw }, 10, 10);
  assert.equal(map.available, true);
  assert.equal(map.certified, false);
  assert.equal(map.inBounds, 1);
  assert.equal(map.outOfBounds, 1);
  assert.equal(map.sampleCoverage, 0.5);
  assert.ok(map.cells.some((count) => count === 1));
  assert.equal(buildHeatMap([], { sw: sw, se: se, nw: nw }).reason, "NO_TRACK");
  assert.equal(buildHeatMap([inside], null).reason, "NO_CALIBRATION");
  const local = toLocalMeters(sw, inside);
  assert.ok(local.x > 50 && local.x < 55);
  assert.ok(local.y > 30 && local.y < 38);
});
