// Device-app and service file for the screen-off witness.
// Callers decide when a write is allowed. This module does not sample time.

import { readFileSync, writeFileSync } from "@zos/fs";
import { CLOCK_WITNESS } from "./clock_store_paths.js";
import { decodeWitness, emptyWitness, encodeWitness } from "./clock_sleep_witness.js";

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

export function readWitness() {
  try {
    const raw = asText(readFileSync({ path: CLOCK_WITNESS, options: { encoding: "utf8" } }));
    if (!raw) {
      return emptyWitness();
    }
    return decodeWitness(raw);
  } catch (err) {
    if (isAbsence(err)) {
      return emptyWitness();
    }
    throw err;
  }
}

export function writeWitness(witness) {
  writeFileSync({
    path: CLOCK_WITNESS,
    data: encodeWitness(witness),
    options: { encoding: "utf8" },
  });
  return true;
}
