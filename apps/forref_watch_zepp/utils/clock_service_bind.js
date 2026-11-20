// Starts the background sampler only while a verified half is running.
// A denied or failed start is logged and left denied. It is not treated as a clock.

import { queryPermission, requestPermission } from "@zos/app";
import { start, stop } from "@zos/app-service";
import { isRunning, Trust } from "./match_clock";

const PERMISSION = "device:os.bg_service";
const SERVICE_FILE = "app-service/clock_service";

let running = false;
let pending = false;
let denied = false;

function statusGranted(result) {
  if (Array.isArray(result)) {
    return result[0] === 2 || result[0] === "granted";
  }
  if (result && typeof result === "object") {
    const value = result[PERMISSION];
    return value === 2 || value === "granted";
  }
  return false;
}

function statusDenied(result) {
  if (Array.isArray(result)) {
    return result[0] === 1 || result[0] === "denied";
  }
  if (result && typeof result === "object") {
    const value = result[PERMISSION];
    return value === 1 || value === "denied";
  }
  return false;
}

function launch() {
  let code;
  try {
    code = start({
      file: SERVICE_FILE,
      param: "",
      reload: false,
      complete_func: function (option) {
        const ok = option && (option.result === true || option.result === 0);
        console.log("FORREF_CLOCK_SLEEP start=" + (ok ? "ok" : "fail"));
      },
    });
  } catch (err) {
    console.log("FORREF_CLOCK_SLEEP start=unavailable");
    return;
  }
  console.log("FORREF_CLOCK_SLEEP code=" + code);
  if (code === 0 || code === true) {
    running = true;
  }
}

function ensureStarted() {
  if (running || pending || denied) {
    return;
  }
  pending = true;
  try {
    queryPermission({
      permissions: [PERMISSION],
      callback: function (result) {
        pending = false;
        if (statusGranted(result)) {
          launch();
          return;
        }
        if (statusDenied(result)) {
          denied = true;
          console.log("FORREF_CLOCK_SLEEP perm=denied");
          return;
        }
        try {
          requestPermission({
            permissions: [PERMISSION],
            callback: function (next) {
              if (statusGranted(next)) {
                launch();
                return;
              }
              denied = true;
              console.log("FORREF_CLOCK_SLEEP perm=denied");
            },
          });
        } catch (err) {
          denied = true;
          console.log("FORREF_CLOCK_SLEEP perm=unavailable");
        }
      },
    });
  } catch (err) {
    pending = false;
    denied = true;
    console.log("FORREF_CLOCK_SLEEP perm=unavailable");
  }
}

function stopService() {
  if (!running) {
    return;
  }
  try {
    stop();
  } catch (err) {
    console.log("FORREF_CLOCK_SLEEP stop=unavailable");
  }
  running = false;
}

export function syncClockService(session) {
  const needed = !!(session && isRunning(session.phase) && session.trust !== Trust.UNVERIFIED);
  if (!needed) {
    stopService();
    return;
  }
  ensureStarted();
}
