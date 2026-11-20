// Screen-off checkpoint. File writes are the App Service path.
// LocalStorage is not used here: the service must still load if that module is unavailable.

import { Time } from "@zos/sensor";
import { readFileSync, writeFileSync } from "@zos/fs";
import { CLOCK_FILE, CLOCK_MIRROR } from "./clock_store_paths.js";

const clock = new Time();

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

function isAbsence(err) {
  const text = String(err && err.message ? err.message : err);
  return /not found|no such|not exist|enoent|empty|undefined/i.test(text);
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

export function serviceNow() {
  try {
    const value = clock.getTime();
    if (typeof value !== "number" || !isFinite(value)) {
      return null;
    }
    return value < 1e11 ? Math.round(value * 1000) : Math.round(value);
  } catch (err) {
    return null;
  }
}

export function serviceAdapter() {
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
    writeKv() {
      return false;
    },
    readKv() {
      return "";
    },
  };
}
