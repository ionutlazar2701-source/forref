// CLOCK-004 UTC segment store. Elapsed time is anchor plus (now - anchor).
// A paint does not add a second and does not rewrite the slot.
// v1 forref_clock001c_* files are read once and never rewritten here.

import {
  Phase,
  REGULATION_HALF_MS,
  Trust,
  cloneSession,
  decodeSession,
  freshSession,
  fnv32,
  isUtcSegment,
  loadSession,
  readCheckpointRaw,
} from "./match_clock.js";

export function openUtcSession(epoch, halfLimitMs) {
  const session = freshSession();
  session.engine = "utc_segment";
  session.integrity = "UTC_ASSUMED";
  session.halfLimitMs = positiveLimit(halfLimitMs);
  session.epoch = epoch || null;
  session.notice = "NO_PRIOR_PROOF";
  return session;
}

function positiveLimit(value) {
  return typeof value === "number" && isFinite(value) && value > 0 ? value : REGULATION_HALF_MS;
}

function bodyOf(session) {
  return {
    v: 2,
    engine: "utc_segment",
    seq: session.seq,
    phase: session.phase,
    trust: session.trust,
    integrity: session.integrity || "UTC_ASSUMED",
    h1: session.firstHalfClosedMs,
    h2: session.secondHalfClosedMs,
    open: session.openStartUtc,
    last: session.lastUtc,
    epoch: session.epoch,
    ids: session.appliedIntentIds,
    notice: session.notice,
    slot: session.periodSlot,
    journal: session.journal,
    halfLimitMs: positiveLimit(session.halfLimitMs),
  };
}

export function encodeSegment(session) {
  const raw = JSON.stringify(bodyOf(session));
  return JSON.stringify({ v: 2, raw: raw, hash: fnv32(raw) });
}

export function decodeSegment(text) {
  if (!text) {
    return { ok: false, reason: "EMPTY" };
  }
  let shell;
  try {
    shell = JSON.parse(text);
  } catch (err) {
    return { ok: false, reason: "CORRUPT" };
  }
  if (!shell || shell.v !== 2 || typeof shell.raw !== "string" || shell.hash !== fnv32(shell.raw)) {
    return { ok: false, reason: "CORRUPT" };
  }
  let body;
  try {
    body = JSON.parse(shell.raw);
  } catch (err) {
    return { ok: false, reason: "CORRUPT" };
  }
  if (!body || body.v !== 2 || body.engine !== "utc_segment" || typeof body.seq !== "number") {
    return { ok: false, reason: "CORRUPT" };
  }
  const session = freshSession();
  session.engine = "utc_segment";
  session.seq = body.seq;
  session.phase = body.phase || Phase.READY;
  session.trust = body.trust || Trust.UNVERIFIED;
  session.integrity = body.integrity || "UTC_ASSUMED";
  session.firstHalfClosedMs = numberOrZero(body.h1);
  session.secondHalfClosedMs = numberOrZero(body.h2);
  session.openStartUtc = body.open == null ? null : body.open;
  session.lastUtc = body.last == null ? null : body.last;
  session.epoch = body.epoch || null;
  session.appliedIntentIds = Array.isArray(body.ids) ? body.ids.slice() : [];
  session.notice = body.notice || "";
  session.periodSlot = body.slot === 2 ? 2 : 1;
  session.journal = Array.isArray(body.journal)
    ? body.journal.map(function (entry) {
        return Object.assign({}, entry);
      })
    : [];
  session.halfLimitMs = positiveLimit(body.halfLimitMs);
  return { ok: true, session: session };
}

function numberOrZero(value) {
  return typeof value === "number" && isFinite(value) && value >= 0 ? value : 0;
}

function readSlot(adapter, which) {
  try {
    const text = which === "A" ? adapter.readA() : adapter.readB();
    if (text == null || text === "") {
      return { ok: false, reason: "EMPTY" };
    }
    return decodeSegment(String(text));
  } catch (err) {
    return { ok: false, reason: "CORRUPT" };
  }
}

export function readSegment(adapter) {
  const a = readSlot(adapter, "A");
  const b = readSlot(adapter, "B");
  if (!a.ok && !b.ok) {
    if (a.reason === "EMPTY" && b.reason === "EMPTY") {
      return { ok: false, reason: "EMPTY" };
    }
    return { ok: false, reason: "CORRUPT" };
  }
  if (a.ok && b.ok) {
    if (a.session.seq === b.session.seq && encodeSegment(a.session) !== encodeSegment(b.session)) {
      return { ok: false, reason: "CONFLICT" };
    }
    const newer = a.session.seq >= b.session.seq ? a.session : b.session;
    return { ok: true, session: newer, reason: a.session.seq === b.session.seq ? "PAIR" : "NEWER" };
  }
  return { ok: true, session: a.ok ? a.session : b.session, reason: "SINGLE" };
}

export function commitSegment(adapter, session) {
  if (!isUtcSegment(session)) {
    return { ok: false, reason: "ENGINE", session: session };
  }
  const current = readSegment(adapter);
  if (current.reason === "CORRUPT" || current.reason === "CONFLICT") {
    return { ok: false, reason: current.reason, session: session };
  }
  if (current.ok && session.seq < current.session.seq) {
    return { ok: false, reason: "STALE", session: current.session };
  }
  if (current.ok && session.seq === current.session.seq) {
    if (encodeSegment(session) === encodeSegment(current.session)) {
      return { ok: true, reason: "SAME", session: session };
    }
    return { ok: false, reason: "CONFLICT", session: session };
  }
  const raw = encodeSegment(session);
  const slot = session.seq % 2 === 0 ? "A" : "B";
  let wrote = false;
  try {
    wrote = (slot === "A" ? adapter.writeA(raw) : adapter.writeB(raw)) === true;
  } catch (err) {
    wrote = false;
  }
  if (!wrote) {
    return { ok: false, reason: "WRITE", session: session };
  }
  let back = "";
  try {
    back = slot === "A" ? adapter.readA() : adapter.readB();
  } catch (err) {
    back = "";
  }
  if (back !== raw) {
    return { ok: false, reason: "READBACK", session: session };
  }
  return { ok: true, reason: "COMMITTED", session: session };
}

function engineMode(adapter) {
  if (!adapter || typeof adapter.readEngine !== "function") {
    return "";
  }
  try {
    return String(adapter.readEngine() || "").trim();
  } catch (err) {
    return "";
  }
}

function stampMigrated(session) {
  const next = cloneSession(session);
  next.engine = "utc_segment";
  next.halfLimitMs = positiveLimit(next.halfLimitMs);
  next.integrity = next.trust === Trust.UNVERIFIED ? "TIME_UNKNOWN" : "UTC_ASSUMED";
  return next;
}

function readLegacy(legacy) {
  const found = readCheckpointRaw(legacy);
  if (!found.ok) {
    return { ok: false, reason: found.reason === "STORE_UNAVAILABLE" ? "STORE_UNAVAILABLE" : "CONFLICT" };
  }
  if (!found.raw) {
    return { ok: true, reason: "EMPTY", session: null };
  }
  const decoded = decodeSession(found.raw);
  if (!decoded) {
    return { ok: false, reason: "CORRUPT" };
  }
  return { ok: true, reason: "LEGACY", session: decoded };
}

function failed(epoch, reason) {
  const session = openUtcSession(epoch);
  session.trust = Trust.UNVERIFIED;
  session.integrity = "TIME_UNKNOWN";
  session.notice = reason;
  session.phase = Phase.READY;
  return { session: session, reason: reason, engine: "utc_segment" };
}

export function loadLiveClock(segment, legacy, epoch, now) {
  if (engineMode(segment) === "sampler") {
    const loaded = loadSession(legacy, epoch, now);
    const session = cloneSession(loaded.session);
    session.engine = "sampler";
    return { session: session, reason: loaded.reason, engine: "sampler" };
  }
  const stored = readSegment(segment);
  if (stored.reason === "CORRUPT" || stored.reason === "CONFLICT") {
    return failed(epoch, stored.reason);
  }
  if (stored.ok) {
    return { session: stored.session, reason: "SEGMENT_" + stored.reason, engine: "utc_segment" };
  }
  const prior = readLegacy(legacy);
  if (!prior.ok) {
    return failed(epoch, "LEGACY_" + prior.reason);
  }
  if (!prior.session || prior.session.seq === 0) {
    return { session: openUtcSession(epoch), reason: "NO_PRIOR_PROOF", engine: "utc_segment" };
  }
  const migrated = stampMigrated(prior.session);
  const kind = migrated.trust === Trust.UNVERIFIED ? "UNVERIFIED" : migrated.openStartUtc != null ? "ANCHOR" : "FROZEN";
  return { session: migrated, reason: "MIGRATED_" + kind, engine: "utc_segment" };
}
