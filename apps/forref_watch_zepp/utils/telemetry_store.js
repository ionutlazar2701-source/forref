import { readFileSync, writeFileSync } from "@zos/fs";

const FILE = "forref_tel_002_state.txt";
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

export function deviceTelemetryStore() {
  return {
    read: function () {
      try {
        return asText(readFileSync({ path: FILE, options: { encoding: "utf8" } }));
      } catch (err) {
        return "";
      }
    },
    write: function (line) {
      if (typeof line !== "string" || line.length > MAX_BYTES) {
        return { ok: false, reason: "CAPACITY" };
      }
      writeFileSync({ path: FILE, data: line, options: { encoding: "utf8" } });
      return { ok: true };
    },
  };
}
