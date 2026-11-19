import { readFileSync, writeFileSync } from "@zos/fs";

// Provisional totals only. Isolated from the clock file and from Match Memory.
const FILE = "forref_tel_003_state.txt";
const MAX_BYTES = 192;

function asText(value) {
  if (value == null) {
    return "";
  }
  if (typeof value === "string") {
    return value;
  }
  if (typeof value === "object" && typeof value.data === "string") {
    return value.data;
  }
  return "";
}

function messageOf(err) {
  return String(err && err.message ? err.message : err);
}

function isAbsence(err) {
  return /not found|no such|not exist|enoent|empty|undefined/i.test(messageOf(err));
}

function isCapacity(err) {
  return /full|space|quota|capacity|enospc|too large/i.test(messageOf(err));
}

export function deviceTelemetryStore() {
  return {
    read: function () {
      try {
        const text = asText(readFileSync({ path: FILE, options: { encoding: "utf8" } }));
        if (!text) {
          return { status: "NOT_FOUND", text: "" };
        }
        return { status: "OK", text: text };
      } catch (err) {
        if (isAbsence(err)) {
          return { status: "NOT_FOUND", text: "" };
        }
        return { status: "READ_FAILED", text: "" };
      }
    },
    write: function (line) {
      if (typeof line !== "string" || line.length === 0) {
        return { ok: false, reason: "SHORT_WRITE" };
      }
      if (line.length > MAX_BYTES) {
        return { ok: false, reason: "CAPACITY" };
      }
      try {
        writeFileSync({ path: FILE, data: line, options: { encoding: "utf8" } });
      } catch (err) {
        if (isCapacity(err)) {
          return { ok: false, reason: "CAPACITY" };
        }
        return { ok: false, reason: "WRITE_FAILED" };
      }
      let back = "";
      try {
        back = asText(readFileSync({ path: FILE, options: { encoding: "utf8" } }));
      } catch (err) {
        return { ok: false, reason: "READ_FAILED" };
      }
      if (back !== line) {
        return { ok: false, reason: "SHORT_WRITE" };
      }
      return { ok: true, reason: "READBACK" };
    },
  };
}
