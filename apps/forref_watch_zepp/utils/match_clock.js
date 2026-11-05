// Prototype watch-client instrument. Not Match Memory, not D1, not a certified clock.
// Elapsed comes from injected UTC observations. A UI callback must not add one second.
// 45:00 and 90:00 are display marks. They never end a period.

export const REGULATION_HALF_MS = 45 * 60 * 1000;
export const MAX_SAME_SESSION_GAP_MS = 120 * 1000;
export const JOURNAL_LIMIT = 30;

export const Phase = {
  READY: "READY",
  FIRST_HALF_RUNNING: "FIRST_HALF_RUNNING",
  FIRST_HALF_PAUSED: "FIRST_HALF_PAUSED",
  HALF_TIME: "HALF_TIME",
  SECOND_HALF_RUNNING: "SECOND_HALF_RUNNING",
  SECOND_HALF_PAUSED: "SECOND_HALF_PAUSED",
  FULL_TIME: "FULL_TIME",
};

export const Trust = {
  OBSERVED: "OBSERVED_UNVERIFIED",
  UNVERIFIED: "TIME_UNVERIFIED",
  FROZEN: "FROZEN_OBSERVED",
};

const SHORT = {
  READY: "RDY",
  FIRST_HALF_RUNNING: "H1R",
  FIRST_HALF_PAUSED: "H1P",
  HALF_TIME: "HT",
  SECOND_HALF_RUNNING: "H2R",
  SECOND_HALF_PAUSED: "H2P",
  FULL_TIME: "FT",
};

export function freshSession() {
  return {
    phase: Phase.READY,
    trust: Trust.FROZEN,
    firstHalfClosedMs: 0,
    secondHalfClosedMs: 0,
    openStartUtc: null,
    lastUtc: null,
    epoch: null,
    appliedIntentIds: [],
    journal: [],
    notice: "FRESH",
    seq: 0,
  };
}

export function isRunning(phase) {
  return phase === Phase.FIRST_HALF_RUNNING || phase === Phase.SECOND_HALF_RUNNING;
}

function isSecond(phase) {
  return (
    phase === Phase.SECOND_HALF_RUNNING ||
    phase === Phase.SECOND_HALF_PAUSED ||
    phase === Phase.FULL_TIME
  );
}

export function cloneSession(session) {
  return {
    phase: session.phase,
    trust: session.trust,
    firstHalfClosedMs: session.firstHalfClosedMs,
    secondHalfClosedMs: session.secondHalfClosedMs,
    openStartUtc: session.openStartUtc,
    lastUtc: session.lastUtc,
    epoch: session.epoch,
    appliedIntentIds: session.appliedIntentIds.slice(),
    journal: session.journal.map((entry) => Object.assign({}, entry)),
    notice: session.notice,
    seq: session.seq,
  };
}

function pad(value) {
  const text = String(value);
  return text.length < 2 ? "0" + text : text;
}

export function formatElapsed(ms) {
  const safe = ms < 0 ? 0 : ms;
  const total = Math.floor(safe / 1000);
  return pad(Math.floor(total / 60)) + ":" + pad(total % 60);
}

function addToOpenPeriod(session, delta) {
  if (delta <= 0) {
    return;
  }
  if (isSecond(session.phase)) {
    session.secondHalfClosedMs += delta;
  } else {
    session.firstHalfClosedMs += delta;
  }
}

function foldOpen(session, utc) {
  if (session.openStartUtc == null || utc == null) {
    session.openStartUtc = null;
    return true;
  }
  const delta = utc - session.openStartUtc;
  const step = session.lastUtc == null ? delta : utc - session.lastUtc;
  if (delta < 0 || step < 0 || step > MAX_SAME_SESSION_GAP_MS) {
    return false;
  }
  addToOpenPeriod(session, delta);
  session.openStartUtc = null;
  session.lastUtc = utc;
  return true;
}

function closeAtLastGood(session) {
  if (session.openStartUtc != null && session.lastUtc != null) {
    const good = session.lastUtc - session.openStartUtc;
    if (good >= 0) {
      addToOpenPeriod(session, good);
    }
  }
  session.openStartUtc = null;
}

function failClosed(session, utc, reason) {
  closeAtLastGood(session);
  session.trust = Trust.UNVERIFIED;
  session.notice = reason;
  session.lastUtc = utc;
  return { session: session, event: "UNVERIFIED" };
}

export function sample(session, observation) {
  const next = cloneSession(session);
  const utc = observation.utcMillis;
  if (!isRunning(next.phase) || next.trust === Trust.UNVERIFIED) {
    return { session: next, event: "HELD" };
  }
  if (observation.discontinuity) {
    return failClosed(next, utc, observation.discontinuity);
  }
  if (next.epoch && observation.epoch && observation.epoch !== next.epoch) {
    return failClosed(next, utc, "EPOCH");
  }
  if (next.openStartUtc == null || utc == null) {
    return failClosed(next, utc, "CLOCK_UNAVAILABLE");
  }
  const anchor = next.lastUtc == null ? next.openStartUtc : next.lastUtc;
  const delta = utc - anchor;
  if (delta < 0) {
    return failClosed(next, utc, "BACKWARD");
  }
  if (delta > MAX_SAME_SESSION_GAP_MS) {
    return failClosed(next, utc, "FORWARD_GAP");
  }
  next.lastUtc = utc;
  next.notice = "";
  return { session: next, event: "TICK" };
}

function reject(session, reason) {
  return { ok: false, duplicate: false, reason: reason, session: session };
}

function pausedPhase(phase) {
  if (phase === Phase.FIRST_HALF_RUNNING || phase === Phase.FIRST_HALF_PAUSED) {
    return Phase.FIRST_HALF_PAUSED;
  }
  if (phase === Phase.SECOND_HALF_RUNNING || phase === Phase.SECOND_HALF_PAUSED) {
    return Phase.SECOND_HALF_PAUSED;
  }
  return null;
}

export function applyIntent(session, intent, observation) {
  const id = observation.intentId;
  if (!id) {
    return reject(session, "INTENT_ID");
  }
  if (session.appliedIntentIds.indexOf(id) >= 0) {
    return { ok: false, duplicate: true, reason: "DUPLICATE", session: session };
  }
  if (session.trust === Trust.UNVERIFIED && intent !== "CONTINUE_FROM_LAST") {
    return reject(session, "UNVERIFIED");
  }

  let current = session;
  if (isRunning(session.phase) && session.trust !== Trust.UNVERIFIED) {
    const sampled = sample(session, observation);
    current = sampled.session;
    if (current.trust === Trust.UNVERIFIED) {
      return { ok: false, duplicate: false, reason: current.notice, session: current };
    }
  }

  const before = current.phase;
  const next = cloneSession(current);
  const utc = observation.utcMillis;

  if (intent === "KICK_OFF") {
    if (before !== Phase.READY) {
      return reject(current, "ILLEGAL");
    }
    next.phase = Phase.FIRST_HALF_RUNNING;
    next.trust = Trust.OBSERVED;
    next.firstHalfClosedMs = 0;
    next.secondHalfClosedMs = 0;
    next.openStartUtc = utc;
    next.lastUtc = utc;
    next.epoch = observation.epoch || next.epoch;
  } else if (intent === "PAUSE") {
    if (!isRunning(before)) {
      return reject(current, "ILLEGAL");
    }
    if (!foldOpen(next, utc)) {
      return failIntent(next, utc, "FORWARD_GAP");
    }
    next.phase = pausedPhase(before);
    next.trust = Trust.FROZEN;
  } else if (intent === "RESUME") {
    if (before !== Phase.FIRST_HALF_PAUSED && before !== Phase.SECOND_HALF_PAUSED) {
      return reject(current, "ILLEGAL");
    }
    next.phase = before === Phase.FIRST_HALF_PAUSED ? Phase.FIRST_HALF_RUNNING : Phase.SECOND_HALF_RUNNING;
    next.trust = Trust.OBSERVED;
    next.openStartUtc = utc;
    next.lastUtc = utc;
    next.epoch = observation.epoch || next.epoch;
  } else if (intent === "END_FIRST_HALF") {
    if (before !== Phase.FIRST_HALF_RUNNING && before !== Phase.FIRST_HALF_PAUSED) {
      return reject(current, "ILLEGAL");
    }
    if (before === Phase.FIRST_HALF_RUNNING && !foldOpen(next, utc)) {
      return failIntent(next, utc, "FORWARD_GAP");
    }
    next.phase = Phase.HALF_TIME;
    next.trust = Trust.FROZEN;
    next.openStartUtc = null;
  } else if (intent === "START_SECOND_HALF") {
    if (before !== Phase.HALF_TIME) {
      return reject(current, "ILLEGAL");
    }
    next.phase = Phase.SECOND_HALF_RUNNING;
    next.trust = Trust.OBSERVED;
    next.secondHalfClosedMs = 0;
    next.openStartUtc = utc;
    next.lastUtc = utc;
    next.epoch = observation.epoch || next.epoch;
  } else if (intent === "FULL_TIME") {
    if (before !== Phase.SECOND_HALF_RUNNING && before !== Phase.SECOND_HALF_PAUSED) {
      return reject(current, "ILLEGAL");
    }
    if (before === Phase.SECOND_HALF_RUNNING && !foldOpen(next, utc)) {
      return failIntent(next, utc, "FORWARD_GAP");
    }
    next.phase = Phase.FULL_TIME;
    next.trust = Trust.FROZEN;
    next.openStartUtc = null;
  } else if (intent === "CONTINUE_FROM_LAST") {
    const landed = pausedPhase(before);
    if (session.trust !== Trust.UNVERIFIED || !landed) {
      return reject(current, "ILLEGAL");
    }
    next.phase = landed;
    next.trust = Trust.FROZEN;
    next.openStartUtc = null;
    next.notice = "GAP_EXCLUDED";
    next.epoch = observation.epoch || next.epoch;
    next.appliedIntentIds = current.appliedIntentIds.concat([id]).slice(-64);
    next.seq = current.seq + 1;
    pushJournal(next, id, intent, before, utc);
    return { ok: true, duplicate: false, reason: "APPLIED", session: next };
  } else {
    return reject(current, "ILLEGAL");
  }

  next.notice = "";
  next.appliedIntentIds = current.appliedIntentIds.concat([id]).slice(-64);
  next.seq = current.seq + 1;
  pushJournal(next, id, intent, before, utc);
  return { ok: true, duplicate: false, reason: "APPLIED", session: next };
}

function failIntent(session, utc, reason) {
  const closed = failClosed(session, utc, reason);
  return { ok: false, duplicate: false, reason: reason, session: closed.session };
}

function pushJournal(session, id, intent, before, utc) {
  session.journal = session.journal.concat([
    {
      seq: session.seq,
      intentId: id,
      intent: intent,
      before: before,
      after: session.phase,
      utc: utc,
      trust: session.trust,
    },
  ]);
  if (session.journal.length > JOURNAL_LIMIT) {
    session.journal = session.journal.slice(session.journal.length - JOURNAL_LIMIT);
  }
}

export function livePeriodMs(session, utc) {
  const base = isSecond(session.phase) ? session.secondHalfClosedMs : session.firstHalfClosedMs;
  if (!isRunning(session.phase) || session.trust === Trust.UNVERIFIED || session.openStartUtc == null || utc == null) {
    return base;
  }
  const delta = utc - session.openStartUtc;
  if (delta < 0) {
    return base;
  }
  return base + delta;
}

export function actionsFor(session) {
  if (session.trust === Trust.UNVERIFIED) {
    if (pausedPhase(session.phase)) {
      return ["CONTINUE_FROM_LAST"];
    }
    return [];
  }
  if (session.phase === Phase.READY) {
    return ["KICK_OFF"];
  }
  if (session.phase === Phase.FIRST_HALF_RUNNING) {
    return ["PAUSE", "END_FIRST_HALF"];
  }
  if (session.phase === Phase.FIRST_HALF_PAUSED) {
    return ["RESUME", "END_FIRST_HALF"];
  }
  if (session.phase === Phase.HALF_TIME) {
    return ["START_SECOND_HALF"];
  }
  if (session.phase === Phase.SECOND_HALF_RUNNING) {
    return ["PAUSE", "FULL_TIME"];
  }
  if (session.phase === Phase.SECOND_HALF_PAUSED) {
    return ["RESUME", "FULL_TIME"];
  }
  return [];
}

export function present(session, utc) {
  const unverified = session.trust === Trust.UNVERIFIED;
  let digits = null;
  let added = false;
  let mark = null;
  if (!unverified) {
    if (session.phase === Phase.READY) {
      digits = formatElapsed(0);
    } else if (session.phase === Phase.HALF_TIME) {
      const shown = splitRegulation(session.firstHalfClosedMs, REGULATION_HALF_MS, 45);
      digits = shown.digits;
      added = shown.added;
      mark = shown.mark;
    } else if (isSecond(session.phase)) {
      const presentation = REGULATION_HALF_MS + livePeriodMs(session, utc);
      const shown = splitRegulation(presentation, REGULATION_HALF_MS * 2, 90);
      digits = shown.digits;
      added = shown.added;
      mark = shown.mark;
    } else {
      const shown = splitRegulation(livePeriodMs(session, utc), REGULATION_HALF_MS, 45);
      digits = shown.digits;
      added = shown.added;
      mark = shown.mark;
    }
  }
  const known = isSecond(session.phase) ? session.secondHalfClosedMs : session.firstHalfClosedMs;
  return {
    unverified: unverified,
    phase: session.phase,
    trust: session.trust,
    notice: session.notice,
    digits: digits,
    added: added,
    mark: mark,
    lastKnown: formatElapsed(known),
    running: isRunning(session.phase) && !unverified,
    actions: actionsFor(session),
    firstHalfMs: session.firstHalfClosedMs,
    secondHalfMs: session.secondHalfClosedMs,
  };
}

function splitRegulation(ms, limit, mark) {
  if (ms > limit) {
    return { digits: formatElapsed(ms - limit), added: true, mark: mark };
  }
  return { digits: formatElapsed(ms), added: false, mark: null };
}

export function displayText(view) {
  if (!view || view.unverified || view.digits == null) {
    return null;
  }
  if (view.added) {
    return view.mark + " + " + view.digits;
  }
  return view.digits;
}

export function trace(kind, before, session, utc) {
  const view = present(session, utc);
  const shown = view.unverified ? "UNVERIFIED" : view.digits == null ? "-" : displayText(view);
  return (
    "FORREF_CLOCK001 " +
    kind +
    "|" +
    (SHORT[before] || "-") +
    ">" +
    (SHORT[session.phase] || "-") +
    "|" +
    (utc == null ? 0 : utc) +
    "|" +
    shown +
    "|" +
    session.trust +
    "!"
  );
}

export function fnv32(text) {
  let hash = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  return (hash >>> 0).toString(16).padStart(8, "0");
}

export function encodeSession(session) {
  const body = {
    v: 1,
    phase: session.phase,
    trust: session.trust,
    h1: session.firstHalfClosedMs,
    h2: session.secondHalfClosedMs,
    open: session.openStartUtc,
    last: session.lastUtc,
    epoch: session.epoch,
    ids: session.appliedIntentIds,
    seq: session.seq,
    notice: session.notice,
    journal: session.journal,
  };
  const json = JSON.stringify(body);
  return json + "#" + fnv32(json);
}

export function decodeSession(raw) {
  if (typeof raw !== "string") {
    return null;
  }
  const cut = raw.lastIndexOf("#");
  if (cut <= 0) {
    return null;
  }
  const json = raw.slice(0, cut);
  if (fnv32(json) !== raw.slice(cut + 1)) {
    return null;
  }
  let body;
  try {
    body = JSON.parse(json);
  } catch (err) {
    return null;
  }
  if (!body || body.v !== 1 || !body.phase) {
    return null;
  }
  const session = freshSession();
  session.phase = body.phase;
  session.trust = body.trust || Trust.UNVERIFIED;
  session.firstHalfClosedMs = numberOrZero(body.h1);
  session.secondHalfClosedMs = numberOrZero(body.h2);
  session.openStartUtc = body.open == null ? null : body.open;
  session.lastUtc = body.last == null ? null : body.last;
  session.epoch = body.epoch || null;
  session.appliedIntentIds = Array.isArray(body.ids) ? body.ids.slice() : [];
  session.seq = numberOrZero(body.seq);
  session.notice = body.notice || "";
  session.journal = Array.isArray(body.journal) ? body.journal.slice(-JOURNAL_LIMIT) : [];
  return session;
}

function numberOrZero(value) {
  return typeof value === "number" && isFinite(value) && value >= 0 ? value : 0;
}

function blankUnverified(notice) {
  const session = freshSession();
  session.trust = Trust.UNVERIFIED;
  session.notice = notice;
  return session;
}

export function loadSession(adapter, epoch) {
  const fileRaw = readRaw(adapter, "readFile");
  const kvRaw = readRaw(adapter, "readKv");
  if (!fileRaw.ok || !kvRaw.ok) {
    return { session: blankUnverified("STORE_UNAVAILABLE"), reason: "STORE_UNAVAILABLE" };
  }
  const fileMissing = fileRaw.value === "";
  const kvMissing = kvRaw.value === "";
  if (fileMissing && kvMissing) {
    const fresh = freshSession();
    fresh.notice = "NO_PRIOR_PROOF";
    fresh.epoch = epoch || null;
    return { session: fresh, reason: "NO_PRIOR_PROOF" };
  }
  if (fileMissing || kvMissing || fileRaw.value !== kvRaw.value) {
    return { session: blankUnverified("CONFLICT"), reason: "CONFLICT" };
  }
  const decoded = decodeSession(fileRaw.value);
  if (!decoded) {
    return { session: blankUnverified("CORRUPT"), reason: "CORRUPT" };
  }
  if (isRunning(decoded.phase)) {
    closeAtLastGood(decoded);
    decoded.trust = Trust.UNVERIFIED;
    decoded.notice = "RECOVERY_REQUIRED";
    decoded.epoch = epoch || decoded.epoch;
    return { session: decoded, reason: "RECOVERY_REQUIRED" };
  }
  decoded.epoch = epoch || decoded.epoch;
  decoded.notice = decoded.notice === "GAP_EXCLUDED" ? decoded.notice : "RESTORED_FROZEN";
  return { session: decoded, reason: "RESTORED_FROZEN" };
}

function readRaw(adapter, method) {
  try {
    const value = adapter[method]();
    if (value == null) {
      return { ok: true, value: "" };
    }
    return { ok: true, value: String(value) };
  } catch (err) {
    return { ok: false, value: "" };
  }
}

export function commitSession(adapter, session) {
  const raw = encodeSession(session);
  let wroteFile = false;
  let wroteKv = false;
  try {
    wroteFile = adapter.writeFile(raw) === true;
  } catch (err) {
    wroteFile = false;
  }
  try {
    wroteKv = adapter.writeKv(raw) === true;
  } catch (err) {
    wroteKv = false;
  }
  const fileRead = readRaw(adapter, "readFile");
  const kvRead = readRaw(adapter, "readKv");
  if (!wroteFile || !wroteKv || !fileRead.ok || !kvRead.ok || fileRead.value !== raw || kvRead.value !== raw) {
    return { ok: false, reason: "READBACK", session: null };
  }
  return { ok: true, reason: "READBACK_ONLY_NOT_D1", session: session };
}

export function advance(session, toUtc, epoch) {
  let current = session;
  let cursor = current.lastUtc == null ? 0 : current.lastUtc;
  while (cursor + MAX_SAME_SESSION_GAP_MS < toUtc) {
    cursor += MAX_SAME_SESSION_GAP_MS;
    const stepped = sample(current, { utcMillis: cursor, epoch: epoch || current.epoch });
    current = stepped.session;
    if (current.trust === Trust.UNVERIFIED) {
      return current;
    }
  }
  return sample(current, { utcMillis: toUtc, epoch: epoch || current.epoch }).session;
}
