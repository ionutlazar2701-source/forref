// CLOCK-006 diagnostic. This build records a phone-time callback and leaves
// the UTC segment in place. It is not a production authorization to ignore
// a real civil-time change. PHONE_OBSERVE false still fail-closes.

export const PHONE_OBSERVE = true;

function num(value) {
  return value == null || !isFinite(value) ? "" : String(value);
}

export function emptyAnchor() {
  return {
    openStartUtc: null,
    lastUtc: null,
    firstHalfClosedMs: 0,
    secondHalfClosedMs: 0,
    seq: null,
    epoch: "",
    phase: "",
    phoneCount: 0,
    phoneUtc: null,
  };
}

export function sealFromSession(session) {
  if (!session || session.engine !== "utc_segment") {
    return null;
  }
  if (session.trust === "TIME_UNVERIFIED" || session.openStartUtc == null) {
    return null;
  }
  return {
    openStartUtc: session.openStartUtc,
    lastUtc: session.lastUtc,
    firstHalfClosedMs: session.firstHalfClosedMs || 0,
    secondHalfClosedMs: session.secondHalfClosedMs || 0,
    seq: session.seq,
    epoch: session.epoch || "",
    phase: session.phase || "",
    phoneCount: 0,
    phoneUtc: null,
  };
}

export function notePhoneEvent(record, utc) {
  const next = Object.assign(emptyAnchor(), record || {});
  next.phoneCount = (next.phoneCount || 0) + 1;
  next.phoneUtc = utc == null ? null : utc;
  return next;
}

export function encodeAnchor(record) {
  const row = Object.assign(emptyAnchor(), record || {});
  return [
    "v=1",
    "open=" + num(row.openStartUtc),
    "last=" + num(row.lastUtc),
    "c1=" + num(row.firstHalfClosedMs),
    "c2=" + num(row.secondHalfClosedMs),
    "seq=" + num(row.seq),
    "epoch=" + (row.epoch || ""),
    "phase=" + (row.phase || ""),
    "phone=" + num(row.phoneCount),
    "phoneUtc=" + num(row.phoneUtc),
  ].join("\n");
}

function field(text, name) {
  const lines = String(text || "").split("\n");
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].indexOf(name + "=") === 0) {
      return lines[i].slice(name.length + 1);
    }
  }
  return "";
}

function parseNum(text) {
  if (text == null || text === "") {
    return null;
  }
  const value = Number(text);
  return isFinite(value) ? value : null;
}

export function decodeAnchor(text) {
  if (!text || String(text).indexOf("v=1") !== 0) {
    return null;
  }
  return {
    openStartUtc: parseNum(field(text, "open")),
    lastUtc: parseNum(field(text, "last")),
    firstHalfClosedMs: parseNum(field(text, "c1")) || 0,
    secondHalfClosedMs: parseNum(field(text, "c2")) || 0,
    seq: parseNum(field(text, "seq")),
    epoch: field(text, "epoch"),
    phase: field(text, "phase"),
    phoneCount: parseNum(field(text, "phone")) || 0,
    phoneUtc: parseNum(field(text, "phoneUtc")),
  };
}

export function formatPhone(row) {
  return (
    "FORREF_CLOCK006 PHONE callback=1 source=onPhoneTimeSetting mode=" +
    (row.observe ? "observe" : "enforce") +
    " utc=" +
    num(row.utc) +
    " anchor=" +
    num(row.anchor) +
    " open=" +
    num(row.open) +
    " epoch=" +
    (row.epoch || "") +
    " seq=" +
    num(row.seq) +
    " phase=" +
    (row.phase || "") +
    " trust=" +
    (row.trust || "") +
    " screen=" +
    (row.screen || "")
  );
}

export function formatUnknown(row) {
  return (
    "FORREF_CLOCK006 UNKNOWN reason=" +
    (row.reason || "") +
    " utc=" +
    num(row.utc) +
    " anchor=" +
    num(row.anchor) +
    " open=" +
    num(row.open) +
    " epoch=" +
    (row.epoch || "") +
    " seq=" +
    num(row.seq) +
    " persist=" +
    (row.persist || "")
  );
}

export function formatLife(kind, row) {
  const fields = row || {};
  return "FORREF_CLOCK006 LIFE kind=" + kind + " epoch=" + (fields.epoch || "") + " utc=" + num(fields.utc);
}
