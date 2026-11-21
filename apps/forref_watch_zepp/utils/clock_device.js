import { Time } from "@zos/sensor";
import { LocalStorage } from "@zos/storage";
import { readFileSync, writeFileSync } from "@zos/fs";
import { getSettings } from "@zos/display";
import {
  CLOCK_ENGINE,
  CLOCK_FILE,
  CLOCK_KEY,
  CLOCK_MIRROR,
  CLOCK_SEGMENT_A,
  CLOCK_SEGMENT_B,
} from "./clock_store_paths.js";
import { screenLabel } from "./clock_service_policy.js";

// 001c is a new prototype generation so a fresh READY can be tested.
// The previous 001b full-time copy, and the probe files, are left in place.
const time = new Time();
let kv = null;

function localStore() {
  if (!kv) {
    kv = new LocalStorage();
  }
  return kv;
}

function writeText(path, raw) {
  writeFileSync({ path: path, data: raw, options: { encoding: "utf8" } });
  return true;
}

function readText(path) {
  try {
    return asText(readFileSync({ path: path, options: { encoding: "utf8" } }));
  } catch (err) {
    if (isAbsence(err)) {
      return "";
    }
    throw err;
  }
}
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

export function deviceScreen() {
  try {
    return screenLabel(getSettings());
  } catch (err) {
    return "unavailable";
  }
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

export function segmentAdapter() {
  return {
    readA() {
      return readText(CLOCK_SEGMENT_A);
    },
    writeA(raw) {
      return writeText(CLOCK_SEGMENT_A, raw);
    },
    readB() {
      return readText(CLOCK_SEGMENT_B);
    },
    writeB(raw) {
      return writeText(CLOCK_SEGMENT_B, raw);
    },
    readEngine() {
      return readText(CLOCK_ENGINE);
    },
    writeEngine(raw) {
      return writeText(CLOCK_ENGINE, raw);
    },
  };
}

export function watchPhoneTime(onChange) {
  try {
    time.onPhoneTimeSetting(function () {
      onChange();
    });
    return true;
  } catch (err) {
    return false;
  }
}

export function deviceAdapter() {
  return {
    writeFile(raw) {
      return writeText(CLOCK_FILE, raw);
    },
    readFile() {
      return readText(CLOCK_FILE);
    },
    writeMirror(raw) {
      return writeText(CLOCK_MIRROR, raw);
    },
    readMirror() {
      return readText(CLOCK_MIRROR);
    },
    writeKv(raw) {
      localStore().setItem(CLOCK_KEY, raw);
      return true;
    },
    readKv() {
      try {
        const value = localStore().getItem(CLOCK_KEY);
        return value == null ? "" : String(value);
      } catch (err) {
        return "";
      }
    },
  };
}
