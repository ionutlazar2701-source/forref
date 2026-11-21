// CHRON-004 isolated UTC-segment feasibility experiment.
// UTC_ASSUMED is never FORREF PROVEN_TIME.
export const STATUS = Object.freeze({
  READY: "READY",
  RUNNING: "RUNNING",
  PAUSED: "PAUSED",
  HALF_TIME: "HALF_TIME",
  FULL_TIME: "FULL_TIME",
  TIME_UNKNOWN: "TIME_UNKNOWN",
});
export const SOURCE = "UTC_WALL_CLOCK";
export const MAX_TRIAL_SEGMENT_MS = 6 * 60 * 60 * 1000;

const KEYS = [
  "v",
  "seq",
  "phase",
  "half",
  "h1ClosedMs",
  "segmentBaseMs",
  "anchorUtc",
  "lastActionUtc",
  "integrity",
  "reason",
  "source",
];

function finiteUtc(value) {
  return typeof value === "number" && Number.isFinite(value) && value >= 1e11 && Number.isSafeInteger(value);
}

function nonnegative(value) {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 && Number.isSafeInteger(value);
}

function copy(record, patch) {
  const out = {};
  for (let i = 0; i < KEYS.length; i += 1) {
    const key = KEYS[i];
    out[key] = Object.prototype.hasOwnProperty.call(patch, key) ? patch[key] : record[key];
  }
  return out;
}

export function fresh() {
  return {
    v: 1,
    seq: 0,
    phase: STATUS.READY,
    half: 1,
    h1ClosedMs: 0,
    segmentBaseMs: 0,
    anchorUtc: null,
    lastActionUtc: null,
    integrity: "UTC_ASSUMED",
    reason: "NO_MATCH",
    source: SOURCE,
  };
}

export function validate(record) {
  if (!record || record.v !== 1 || !Number.isSafeInteger(record.seq) || record.seq < 0) {
    return false;
  }
  if (!Object.values(STATUS).includes(record.phase) || ![1, 2].includes(record.half) || record.source !== SOURCE) {
    return false;
  }
  if (!nonnegative(record.h1ClosedMs) || !nonnegative(record.segmentBaseMs)) {
    return false;
  }
  if (!["UTC_ASSUMED", "TIME_UNKNOWN"].includes(record.integrity)) {
    return false;
  }
  if (record.anchorUtc !== null && !finiteUtc(record.anchorUtc)) {
    return false;
  }
  if (record.lastActionUtc !== null && !finiteUtc(record.lastActionUtc)) {
    return false;
  }
  if (record.phase === STATUS.RUNNING && record.integrity !== "TIME_UNKNOWN" && record.anchorUtc === null) {
    return false;
  }
  return true;
}

function unknown(record, reason) {
  return copy(record, {
    phase: STATUS.TIME_UNKNOWN,
    integrity: "TIME_UNKNOWN",
    reason: reason,
    anchorUtc: null,
    seq: record.seq + 1,
  });
}

function live(record, now) {
  if (!validate(record) || !finiteUtc(now)) {
    return { ok: false, reason: "INVALID_SOURCE" };
  }
  if (record.integrity === "TIME_UNKNOWN" || record.phase === STATUS.TIME_UNKNOWN) {
    return { ok: false, reason: record.reason || "TIME_UNKNOWN" };
  }
  if (record.phase !== STATUS.RUNNING) {
    return { ok: true, ms: record.segmentBaseMs };
  }
  const delta = now - record.anchorUtc;
  if (delta < 0) {
    return { ok: false, reason: "CLOCK_BACKWARD" };
  }
  if (delta > MAX_TRIAL_SEGMENT_MS) {
    return { ok: false, reason: "SEGMENT_OUTSIDE_TRIAL_WINDOW" };
  }
  if (!Number.isSafeInteger(delta)) {
    return { ok: false, reason: "UNSAFE_DURATION" };
  }
  return { ok: true, ms: record.segmentBaseMs + delta };
}

function evolve(record, event, now) {
  if (!validate(record) || !finiteUtc(now)) {
    return { ok: false, reason: "BAD_OBSERVATION", record: record };
  }
  if (record.integrity === "TIME_UNKNOWN") {
    return { ok: false, reason: "TIME_UNKNOWN", record: record };
  }
  const next = copy(record, { seq: record.seq + 1, lastActionUtc: now });
  if (event === "KICK_OFF" && record.phase === STATUS.READY) {
    return {
      ok: true,
      record: copy(next, {
        phase: STATUS.RUNNING,
        half: 1,
        segmentBaseMs: 0,
        anchorUtc: now,
        reason: "START",
      }),
    };
  }
  if (event === "START_SECOND_HALF" && record.phase === STATUS.HALF_TIME) {
    return {
      ok: true,
      record: copy(next, {
        phase: STATUS.RUNNING,
        half: 2,
        segmentBaseMs: 0,
        anchorUtc: now,
        reason: "H2",
      }),
    };
  }
  if (event === "RESUME" && record.phase === STATUS.PAUSED) {
    return {
      ok: true,
      record: copy(next, { phase: STATUS.RUNNING, anchorUtc: now, reason: "RESUME" }),
    };
  }
  if (event === "PAUSE" && record.phase === STATUS.RUNNING) {
    const elapsed = live(record, now);
    if (!elapsed.ok) {
      return { ok: false, reason: elapsed.reason, record: record };
    }
    return {
      ok: true,
      record: copy(next, {
        phase: STATUS.PAUSED,
        segmentBaseMs: elapsed.ms,
        anchorUtc: null,
        reason: "PAUSE",
      }),
    };
  }
  if (event === "END_FIRST_HALF" && record.half === 1 && [STATUS.RUNNING, STATUS.PAUSED].includes(record.phase)) {
    const elapsed = live(record, now);
    if (!elapsed.ok) {
      return { ok: false, reason: elapsed.reason, record: record };
    }
    return {
      ok: true,
      record: copy(next, {
        phase: STATUS.HALF_TIME,
        h1ClosedMs: elapsed.ms,
        segmentBaseMs: elapsed.ms,
        anchorUtc: null,
        reason: "HALF_TIME",
      }),
    };
  }
  if (event === "FULL_TIME" && record.half === 2 && [STATUS.RUNNING, STATUS.PAUSED].includes(record.phase)) {
    const elapsed = live(record, now);
    if (!elapsed.ok) {
      return { ok: false, reason: elapsed.reason, record: record };
    }
    return {
      ok: true,
      record: copy(next, {
        phase: STATUS.FULL_TIME,
        segmentBaseMs: elapsed.ms,
        anchorUtc: null,
        reason: "FULL_TIME",
      }),
    };
  }
  return { ok: false, reason: "ILLEGAL_TRANSITION", record: record };
}

export function transition(record, event, now) {
  return evolve(record, event, now);
}

export function phoneTimeChanged(record) {
  if (!validate(record)) {
    return { ok: false, reason: "INVALID_RECORD", record: record };
  }
  return { ok: true, record: unknown(record, "PHONE_TIME_SETTING") };
}

export function formatElapsed(ms) {
  const sec = Math.floor(ms / 1000);
  return String(Math.floor(sec / 60)).padStart(2, "0") + ":" + String(sec % 60).padStart(2, "0");
}

export function readClock(record, now) {
  const elapsed = live(record, now);
  if (!elapsed.ok) {
    return { status: "TIME_UNKNOWN", display: null, elapsedMs: null, reason: elapsed.reason };
  }
  const totalMs = record.half === 2 ? 45 * 60 * 1000 + elapsed.ms : elapsed.ms;
  return {
    status: "UTC_ASSUMED",
    display: formatElapsed(totalMs),
    elapsedMs: totalMs,
    reason: "WALL_CLOCK_CONTINUITY_UNVERIFIED",
  };
}
