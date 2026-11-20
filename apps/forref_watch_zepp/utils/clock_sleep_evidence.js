// Labels for a screen-off log. A label is not match time.
// DISPLAY_CONTINUITY_MS stays the admission rule.

import { DISPLAY_CONTINUITY_MS } from "./match_clock.js";

export function pairProbe(readFile, readMirror) {
  let fileOk = false;
  let mirrorOk = false;
  let file = "";
  let mirror = "";
  try {
    const value = readFile();
    file = value == null ? "" : String(value);
    fileOk = true;
  } catch (err) {
    fileOk = false;
  }
  try {
    const value = readMirror();
    mirror = value == null ? "" : String(value);
    mirrorOk = true;
  } catch (err) {
    mirrorOk = false;
  }
  return {
    fileOk: fileOk,
    mirrorOk: mirrorOk,
    match: fileOk && mirrorOk && file !== "" && file === mirror,
  };
}

export function tickClass(result, probe, dt) {
  const reason = result && result.reason ? result.reason : "";
  if (reason === "UNSAMPLED_GAP" || reason === "BACKWARD" || reason === "EPOCH") {
    return "TIMER_GAP";
  }
  if (reason === "TICK" && (!result || result.wrote !== true || !probe || probe.match !== true)) {
    return "PERSIST";
  }
  if (reason === "TICK") {
    return "CHAIN";
  }
  if (dt != null && dt > DISPLAY_CONTINUITY_MS && reason !== "HELD" && reason !== "STOP") {
    return "TIMER_GAP";
  }
  if (reason === "STOP") {
    return "STOP";
  }
  if (reason === "HELD") {
    return "HELD";
  }
  return reason || "UNKNOWN";
}

export function startClass(code) {
  if (code === 0 || code === true) {
    return "ok";
  }
  if (code === 1) {
    return "param";
  }
  if (code === 2) {
    return "status";
  }
  if (code === 3) {
    return "permission";
  }
  if (code === 4) {
    return "oom";
  }
  if (code === 5) {
    return "unsupported";
  }
  if (code === 6) {
    return "prohibited";
  }
  if (code === 7) {
    return "limit";
  }
  return "unknown";
}

// One label for a finished screen-off attempt. The first broken link wins.
export function classifySleep(trace) {
  const evidence = trace || {};
  if (!evidence.serviceOn) {
    return "SERVICE";
  }
  if (!evidence.timerOn) {
    return "TIMER_CREATE";
  }
  const ticks = evidence.offTicks || [];
  if (ticks.length === 0) {
    return "TIMER_SILENT";
  }
  for (let i = 0; i < ticks.length; i += 1) {
    const tick = ticks[i];
    if (tick.class === "TIMER_GAP" || (tick.dt != null && tick.dt > DISPLAY_CONTINUITY_MS)) {
      return "TIMER_GAP";
    }
  }
  for (let i = 0; i < ticks.length; i += 1) {
    if (ticks[i].class === "PERSIST") {
      return "PERSIST";
    }
  }
  if (evidence.wakeReason === "CONTINUITY_RESUMED") {
    return "CHAIN";
  }
  if (
    evidence.wakeReason === "RECOVERY_REQUIRED" ||
    evidence.wakeReason === "UNSAMPLED_GAP" ||
    evidence.wakeReason === "CONFLICT" ||
    evidence.wakeReason === "STORE_UNAVAILABLE" ||
    evidence.wakeReason === "CORRUPT"
  ) {
    return "RECOVERY";
  }
  return "UNKNOWN";
}
