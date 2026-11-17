import test from "node:test";
import assert from "node:assert/strict";
import { analyzeTrack, buildHeatMap, haversineMeters, toLocalMeters } from "../lib/analytics.js";

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
  ]);
  assert.deepEqual(report.discarded.map((item) => item.reason), ["INVALID_COORD", "NO_FIX", "DUPLICATE", "NON_POSITIVE_TIME", "UNKNOWN_TIME"]);
  assert.equal(report.accepted.length, 1);
  assert.equal(report.distanceMeters, 0);
  assert.equal(report.certifiedDistance, false);
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
  ]);
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
      rows.push({ kind: "LIFECYCLE", name: "DISPLAY_OFF", seq: seq, flags: [] });
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
  const report = analyzeTrack(rows);
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
  const report = analyzeTrack(points);
  assert.equal(report.segments.some((segment) => segment.spike), true);
  assert.ok(report.maxSpeedMps == null || report.maxSpeedMps < 6);
});

test("heart-rate dropouts and the distance sensor stay out of the GNSS distance", () => {
  const origin = { lat: 0, lon: 0 };
  const a = metersPoint(origin, 0, 0);
  const b = metersPoint(origin, 20, 0);
  const report = analyzeTrack([
    gnss(1, 0, a.lat, a.lon),
    { kind: "HR", seq: 2, hrBpm: 140, flags: [] },
    { kind: "HR", seq: 3, hrBpm: null, flags: ["HR_UNAVAILABLE"] },
    { kind: "HR", seq: 4, hrBpm: 0, flags: [] },
    { kind: "HR", seq: 5, hrBpm: 150, flags: [] },
    { kind: "DISTANCE", seq: 6, distanceRaw: 9999, distanceUnit: "UNRESOLVED", distanceAttribution: "UNRESOLVED", flags: ["UNIT_UNRESOLVED"] },
    gnss(7, 10000, b.lat, b.lon),
  ]);
  assert.equal(report.hrCoverage, 0.5);
  assert.equal(report.hrNote, "NOT_A_HEALTH_DIAGNOSIS");
  assert.equal(report.distanceSensorUsedInGnss, false);
  assert.equal(report.distanceSensorUnit, "UNRESOLVED");
  assert.ok(Math.abs(report.distanceMeters - 20) < 1);
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
