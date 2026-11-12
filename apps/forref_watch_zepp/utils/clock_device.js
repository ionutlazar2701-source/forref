import { Time } from "@zos/sensor";
import { LocalStorage } from "@zos/storage";
import { readFileSync, writeFileSync } from "@zos/fs";

// 001c is a new prototype generation so a fresh READY can be tested.
// The previous 001b full-time copy, and the probe files, are left in place.
const FILE = "forref_clock001c_state.json";
const KEY = "forref_clock001c_state";

const time = new Time();
const kv = new LocalStorage();
let loggedSource = false;

function isAbsence(err) {
  const text = String(err && err.message ? err.message : err);
  return /not found|no such|not exist|enoent|empty|undefined/i.test(text);
}

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

export function deviceNow() {
  try {
    const raw = time.getTime();
    if (typeof raw !== "number" || !isFinite(raw)) {
      return null;
    }
    if (!loggedSource) {
      loggedSource = true;
      console.log("FORREF_CLOCK001 SRC|" + raw + "!");
    }
    if (raw < 1e11) {
      return Math.round(raw * 1000);
    }
    return Math.round(raw);
  } catch (err) {
    return null;
  }
}

export function deviceAdapter() {
  return {
    writeFile(raw) {
      writeFileSync({ path: FILE, data: raw, options: { encoding: "utf8" } });
      return true;
    },
    readFile() {
      try {
        return asText(readFileSync({ path: FILE, options: { encoding: "utf8" } }));
      } catch (err) {
        if (isAbsence(err)) {
          return "";
        }
        throw err;
      }
    },
    writeKv(raw) {
      kv.setItem(KEY, raw);
      return true;
    },
    readKv() {
      try {
        const value = kv.getItem(KEY);
        return value == null ? "" : String(value);
      } catch (err) {
        return "";
      }
    },
  };
}
