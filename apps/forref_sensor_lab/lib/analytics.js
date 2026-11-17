// Experimental GNSS analytics. Gaps are measured and never filled in.

export const GAP_MS = 15000;
export const MAX_PLAUSIBLE_SPEED_MPS = 12;
export const STATIONARY_METERS = 4;
export const MIN_SPEED_DT_MS = 1000;
export const SPIKE_SPEED_MPS = 6;

const EARTH_RADIUS_M = 6371000;

export function haversineMeters(a, b) {
  const toRad = (value) => (value * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLon = toRad(b.lon - a.lon);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h = Math.sin(dLat / 2) * Math.sin(dLat / 2) + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)));
}

export function toLocalMeters(origin, point) {
  const latRad = (origin.lat * Math.PI) / 180;
  return {
    x: ((point.lon - origin.lon) * Math.PI / 180) * EARTH_RADIUS_M * Math.cos(latRad),
    y: ((point.lat - origin.lat) * Math.PI / 180) * EARTH_RADIUS_M,
  };
}

function finiteCoord(entry) {
  return entry && typeof entry.lat === "number" && typeof entry.lon === "number" && entry.lat >= -90 && entry.lat <= 90 && entry.lon >= -180 && entry.lon <= 180;
}

function sameFix(a, b) {
  return a.lat === b.lat && a.lon === b.lon && a.diagnosticElapsedMs === b.diagnosticElapsedMs;
}

export function analyzeTrack(entries) {
  const discarded = [];
  const gaps = [];
  const segments = [];
  const accepted = [];
  let previous = null;
  let pauseOpen = false;
  const list = entries || [];
  for (let i = 0; i < list.length; i++) {
    const entry = list[i];
    if (entry.kind === "LIFECYCLE" && (entry.name === "PAUSE" || entry.name === "DISPLAY_OFF")) {
      pauseOpen = true;
      continue;
    }
    if (entry.kind === "LIFECYCLE" && (entry.name === "RESUME" || entry.name === "DISPLAY_ON")) {
      pauseOpen = false;
      continue;
    }
    if (entry.kind === "GAP") {
      gaps.push({
        fromSeq: entry.fromSeq,
        missingMs: entry.missingMs,
        reason: entry.gapReason || "RECORDED",
        seq: entry.seq,
      });
      continue;
    }
    if (entry.kind !== "GNSS") {
      continue;
    }
    if (entry.flags && entry.flags.indexOf("PERMISSION_DENIED") >= 0) {
      discarded.push({ seq: entry.seq, reason: "PERMISSION_DENIED" });
      continue;
    }
    if (entry.gpsStatus !== "A") {
      discarded.push({ seq: entry.seq, reason: "NO_FIX" });
      continue;
    }
    if (!finiteCoord(entry)) {
      discarded.push({ seq: entry.seq, reason: "INVALID_COORD" });
      continue;
    }
    if (previous && sameFix(previous, entry)) {
      discarded.push({ seq: entry.seq, reason: "DUPLICATE" });
      continue;
    }
    if (entry.diagnosticElapsedMs == null) {
      discarded.push({ seq: entry.seq, reason: "UNKNOWN_TIME" });
      continue;
    }
    if (previous && entry.diagnosticElapsedMs <= previous.diagnosticElapsedMs) {
      discarded.push({ seq: entry.seq, reason: "NON_POSITIVE_TIME" });
      continue;
    }
    const dt = previous ? entry.diagnosticElapsedMs - previous.diagnosticElapsedMs : null;
    if (previous && dt > GAP_MS) {
      gaps.push({
        fromSeq: previous.seq,
        toSeq: entry.seq,
        missingMs: dt,
        reason: pauseOpen ? "SCREEN_OFF_OR_PAUSE" : "STALL",
      });
      pauseOpen = false;
      accepted.push(entry);
      previous = entry;
      continue;
    }
    if (previous) {
      const meters = haversineMeters(previous, entry);
      const speed = meters / (dt / 1000);
      if (speed > MAX_PLAUSIBLE_SPEED_MPS) {
        discarded.push({ seq: entry.seq, reason: "TELEPORT" });
        continue;
      }
      segments.push({
        fromSeq: previous.seq,
        toSeq: entry.seq,
        meters: meters,
        dt: dt,
        speed: speed,
        stationary: meters < STATIONARY_METERS,
        spike: false,
      });
    }
    accepted.push(entry);
    previous = entry;
    pauseOpen = false;
  }
  for (let i = 0; i < segments.length; i++) {
    const segment = segments[i];
    const before = i > 0 ? segments[i - 1].speed : null;
    const after = i + 1 < segments.length ? segments[i + 1].speed : null;
    const isolated = segments.length === 1 && segment.speed > SPIKE_SPEED_MPS;
    const surrounded = before != null && after != null && segment.speed > SPIKE_SPEED_MPS && segment.speed > before * 2 && segment.speed > after * 2;
    if (isolated || surrounded) {
      segment.spike = true;
    }
  }
  let distanceMeters = 0;
  let maxSpeed = null;
  for (let i = 0; i < segments.length; i++) {
    const segment = segments[i];
    if (segment.spike || segment.stationary) {
      continue;
    }
    distanceMeters += segment.meters;
    if (segment.dt >= MIN_SPEED_DT_MS && (maxSpeed == null || segment.speed > maxSpeed)) {
      maxSpeed = segment.speed;
    }
  }
  const hr = list.filter((entry) => entry.kind === "HR");
  const hrValid = hr.filter((entry) => entry.hrBpm != null && entry.hrBpm >= 30 && entry.hrBpm <= 230);
  const distanceSensor = list.filter((entry) => entry.kind === "DISTANCE");
  return {
    experimental: true,
    medicalInterpretation: false,
    certifiedDistance: false,
    certifiedSpeed: false,
    accepted: accepted,
    discarded: discarded,
    gaps: gaps,
    segments: segments,
    distanceMeters: distanceMeters,
    maxSpeedMps: maxSpeed,
    maxSpeedReliable: maxSpeed != null,
    missingMs: gaps.reduce((sum, gap) => sum + (gap.missingMs || 0), 0),
    hrSamples: hr.length,
    hrValidSamples: hrValid.length,
    hrCoverage: hr.length === 0 ? null : hrValid.length / hr.length,
    hrNote: "NOT_A_HEALTH_DIAGNOSIS",
    distanceSensorSamples: distanceSensor.length,
    distanceSensorUnit: "UNRESOLVED",
    distanceSensorAttribution: "UNRESOLVED",
    distanceSensorUsedInGnss: false,
  };
}

function solveAxis(origin, axisEnd, point) {
  const axis = toLocalMeters(origin, axisEnd);
  const local = toLocalMeters(origin, point);
  const length = axis.x * axis.x + axis.y * axis.y;
  if (length === 0) {
    return null;
  }
  return (local.x * axis.x + local.y * axis.y) / length;
}

export function buildHeatMap(points, corners, cols, rows) {
  const width = cols || 10;
  const height = rows || 10;
  if (!corners || !corners.sw || !corners.se || !corners.nw) {
    return { available: false, reason: "NO_CALIBRATION", experimental: true, certified: false };
  }
  const list = points || [];
  if (list.length === 0) {
    return { available: false, reason: "NO_TRACK", experimental: true, certified: false };
  }
  const cells = [];
  for (let i = 0; i < width * height; i++) {
    cells.push(0);
  }
  let inBounds = 0;
  let outOfBounds = 0;
  for (let i = 0; i < list.length; i++) {
    const point = list[i];
    if (!finiteCoord(point)) {
      outOfBounds += 1;
      continue;
    }
    const s = solveAxis(corners.sw, corners.se, point);
    const t = solveAxis(corners.sw, corners.nw, point);
    if (s == null || t == null || s < 0 || t < 0 || s > 1 || t > 1) {
      outOfBounds += 1;
      continue;
    }
    const col = Math.min(width - 1, Math.floor(s * width));
    const row = Math.min(height - 1, Math.floor(t * height));
    cells[row * width + col] += 1;
    inBounds += 1;
  }
  const occupied = cells.filter((count) => count > 0).length;
  return {
    available: true,
    reason: "",
    experimental: true,
    certified: false,
    cols: width,
    rows: height,
    cells: cells,
    inBounds: inBounds,
    outOfBounds: outOfBounds,
    sampleCoverage: list.length === 0 ? 0 : inBounds / list.length,
    cellCoverage: occupied / cells.length,
  };
}
