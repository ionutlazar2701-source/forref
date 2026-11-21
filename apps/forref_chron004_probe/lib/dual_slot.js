// Two-slot checksum + readback storage. Mitigates partial writes; not a physical fsync guarantee.
import { validate } from "./chron004.js";

export const SLOT_A = "chron004_A.json";
export const SLOT_B = "chron004_B.json";

export function checksum(text) {
  let hash = 0x811c9dc5;
  for (let i = 0; i < text.length; i += 1) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  return (hash >>> 0).toString(16).padStart(8, "0");
}

export function encode(record) {
  const raw = JSON.stringify(record);
  return JSON.stringify({ raw: raw, hash: checksum(raw) });
}

export function decode(text) {
  try {
    const envelope = JSON.parse(text);
    if (!envelope || typeof envelope.raw !== "string" || envelope.hash !== checksum(envelope.raw)) {
      return null;
    }
    const record = JSON.parse(envelope.raw);
    return validate(record) ? record : null;
  } catch (err) {
    return null;
  }
}

function getSlot(io, name) {
  try {
    const raw = io.read(name);
    return {
      present: typeof raw === "string" && raw.length > 0,
      record: decode(raw),
    };
  } catch (err) {
    const missing = /not found|no such|not exist|enoent/i.test(String(err));
    return { present: !missing, record: null };
  }
}

export function load(io) {
  const left = getSlot(io, SLOT_A);
  const right = getSlot(io, SLOT_B);
  const a = left.record;
  const b = right.record;
  if (!a && !b) {
    return { ok: false, reason: left.present || right.present ? "CORRUPT" : "EMPTY", record: null };
  }
  if (a && b && a.seq === b.seq && JSON.stringify(a) !== JSON.stringify(b)) {
    return { ok: false, reason: "CONFLICT_SAME_SEQ", record: null };
  }
  const record = !b || (a && a.seq >= b.seq) ? a : b;
  return { ok: true, reason: a && b ? "DUAL_SLOT" : "SINGLE_SLOT", record: record };
}

export function commit(io, record) {
  if (!validate(record)) {
    return { ok: false, reason: "INVALID_RECORD" };
  }
  const current = load(io);
  if (!current.ok && current.reason !== "EMPTY") {
    return { ok: false, reason: current.reason };
  }
  if (current.ok && record.seq <= current.record.seq) {
    return { ok: false, reason: "NON_MONOTONIC_SEQ" };
  }
  const slot = record.seq % 2 === 0 ? SLOT_A : SLOT_B;
  try {
    const data = encode(record);
    io.write(slot, data);
    const again = io.read(slot);
    if (again !== data) {
      return { ok: false, reason: "READBACK_MISMATCH" };
    }
    const decoded = decode(again);
    if (!decoded || decoded.seq !== record.seq) {
      return { ok: false, reason: "READBACK_INVALID" };
    }
    return { ok: true, reason: "READBACK_OK", slot: slot };
  } catch (err) {
    return { ok: false, reason: "WRITE_FAILED" };
  }
}
