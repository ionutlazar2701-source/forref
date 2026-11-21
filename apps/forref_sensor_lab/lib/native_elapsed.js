// CLOCK-001 probe. A display string and a timer callback are not proven elapsed time.
// This module does not import Zepp, start a workout, or write Match Memory.

export const PROVEN = "PROVEN_TIME";
export const UNKNOWN = "TIME_UNKNOWN";
export const ERROR_LIMIT_MS = 1000;
export const REQUIRED_SLEEP_SECONDS = Object.freeze([30, 120, 600]);
export const WORKOUT_PERMISSION = "data:user.hd.workout";
export const BIP6_SOURCES = Object.freeze([9765120, 9765121, 10158337]);
export const PROBE_ID = "DUR-001";
export const PROBE_VERSION = "1.0.0";

const ASSERTED_KEYS = Object.freeze([
  "measured",
  "proven",
  "absErrorMs",
  "javascriptTicksUsed",
  "certified",
  "pauseResume",
  "repeatedWakes",
  "bluetoothDrop",
]);

const DOCUMENTED = Object.freeze({
  sport: "https://docs.zepp.com/docs/reference/device-app-api/newAPI/app-access/getSportData/",
  extension: "https://docs.zepp.com/docs/guides/workout-extension/intro/",
  extensionQuick: "https://docs.zepp.com/docs/guides/workout-extension/quick-start/",
  sportWidget: "https://docs.zepp.com/docs/reference/device-app-api/newAPI/ui/widget/SPORT_DATA/",
  workout: "https://docs.zepp.com/docs/reference/device-app-api/newAPI/sensor/Workout/",
  time: "https://docs.zepp.com/docs/reference/device-app-api/newAPI/sensor/Time/",
  sysTimer: "https://docs.zepp.com/docs/reference/device-app-api/newAPI/timer/createSysTimer/",
  service: "https://docs.zepp.com/docs/guides/framework/device/app-service/",
  systemApp: "https://docs.zepp.com/docs/reference/device-app-api/newAPI/router/checkSystemApp/",
  query: "https://docs.zepp.com/docs/reference/device-app-api/newAPI/app/queryPermission/",
  request: "https://docs.zepp.com/docs/reference/device-app-api/newAPI/app/requestPermission/",
});

export function sources() {
  return DOCUMENTED;
}

export function initialProbe() {
  return {
    permission: null,
    permissionReason: "UNREAD",
    requestImmediate: null,
    requestList: null,
    phase: "IDLE",
    accepted: null,
    code: null,
    raw: "",
    durationText: "",
    referee: "",
    reason: "IDLE",
    status: UNKNOWN,
  };
}

export function parseSportDuration(text) {
  const rejected = { ok: false, seconds: null, referee: "", proven: false, reason: "UNDOCUMENTED_SHAPE" };
  if (typeof text !== "string" || !/^(\d+):([0-5]\d):([0-5]\d)$/.test(text)) {
    return rejected;
  }
  const parts = text.split(":");
  const hours = Number(parts[0]);
  const minutes = Number(parts[1]);
  const seconds = Number(parts[2]);
  const total = hours * 3600 + minutes * 60 + seconds;
  return {
    ok: true,
    seconds: total,
    referee: String(hours * 60 + minutes) + ":" + parts[2],
    proven: false,
    reason: "DISPLAY_STRING_NOT_ELAPSED",
  };
}

export function parseSportPayload(data) {
  let parsed = null;
  try {
    parsed = JSON.parse(data);
  } catch (err) {
    parsed = null;
  }
  const row = Array.isArray(parsed) ? parsed[0] : null;
  if (!row || typeof row.duration !== "string") {
    return parseSportDuration("");
  }
  return parseSportDuration(row.duration);
}

export function classifyPermission(value) {
  if (!Array.isArray(value) || value.length < 1 || typeof value[0] !== "number" || !isFinite(value[0])) {
    return { code: null, reason: "PERMISSION_SHAPE" };
  }
  const code = value[0];
  if (code === 2) {
    return { code: 2, reason: "AUTHORIZED" };
  }
  if (code === 0) {
    return { code: 0, reason: "NOT_AUTHORIZED" };
  }
  if (code === 1) {
    return { code: 1, reason: "UNKNOWN_PERMISSION" };
  }
  return { code: code, reason: "PERMISSION_VALUE" };
}

function copyProbe(state, patch) {
  const next = {
    permission: state.permission,
    permissionReason: state.permissionReason,
    requestImmediate: state.requestImmediate,
    requestList: state.requestList,
    phase: state.phase,
    accepted: state.accepted,
    code: state.code,
    raw: state.raw,
    durationText: state.durationText,
    referee: state.referee,
    reason: state.reason,
    status: state.status,
  };
  const keys = Object.keys(patch);
  for (let i = 0; i < keys.length; i += 1) {
    next[keys[i]] = patch[keys[i]];
  }
  return next;
}

export function applyPermissionQuery(state, value) {
  const classified = classifyPermission(value);
  return copyProbe(state, {
    permission: classified.code,
    permissionReason: classified.reason,
  });
}

export function applyPermissionRequest(state, immediate) {
  if (immediate === 0 || immediate === 1 || immediate === 2) {
    return copyProbe(state, { requestImmediate: immediate });
  }
  return copyProbe(state, { requestImmediate: null, permissionReason: "REQUEST_SHAPE" });
}

export function applyPermissionCallback(state, value) {
  const classified = classifyPermission(value);
  return copyProbe(state, {
    requestList: classified.code,
    permission: classified.code,
    permissionReason: classified.reason,
  });
}

function blankReading() {
  return {
    status: UNKNOWN,
    proven: false,
    referee: "",
    seconds: null,
    raw: "",
    durationText: "",
    code: null,
    reason: "",
    accepted: null,
  };
}

function callbackReading(callbackResult) {
  const base = blankReading();
  if (!callbackResult || typeof callbackResult.code !== "number" || !isFinite(callbackResult.code)) {
    base.reason = "SPORT_SHAPE";
    return base;
  }
  const raw = typeof callbackResult.data === "string" ? callbackResult.data : "";
  if (callbackResult.code !== 0) {
    base.reason = "SPORT_CODE";
    base.code = callbackResult.code;
    base.raw = raw;
    return base;
  }
  if (typeof callbackResult.data !== "string") {
    base.reason = "SPORT_DATA_TYPE";
    base.code = 0;
    return base;
  }
  const parsed = parseSportPayload(callbackResult.data);
  base.reason = parsed.reason;
  base.code = 0;
  base.raw = callbackResult.data;
  base.durationText = parsed.ok ? extractDuration(callbackResult.data) : "";
  base.referee = parsed.referee;
  base.seconds = parsed.seconds;
  return base;
}

function extractDuration(data) {
  const parsed = parseSportPayload(data);
  if (!parsed.ok) {
    return "";
  }
  const row = JSON.parse(data)[0];
  return row.duration;
}

export function applySportResult(state, reading) {
  return copyProbe(state, {
    phase: "SETTLED",
    status: reading.status,
    reason: reading.reason,
    accepted: reading.accepted == null ? state.accepted : reading.accepted,
    code: reading.code,
    raw: reading.raw,
    durationText: reading.durationText,
    referee: reading.referee,
  });
}

export function openSportRead(invoke, deliver) {
  if (typeof deliver !== "function") {
    return { phase: "NO_DELIVER", accepted: null };
  }
  if (typeof invoke !== "function") {
    deliver({
      status: UNKNOWN,
      proven: false,
      reason: "NO_READER",
      referee: "",
      seconds: null,
      code: null,
      raw: "",
      durationText: "",
      accepted: null,
    });
    return { phase: "SETTLED", accepted: null };
  }
  let settled = false;
  const finish = function (reading) {
    if (settled) {
      return;
    }
    settled = true;
    deliver(reading);
  };
  let accepted = null;
  try {
    accepted = invoke({ type: "duration" }, function (callbackResult) {
      const reading = callbackReading(callbackResult);
      reading.accepted = true;
      finish(reading);
    });
  } catch (err) {
    finish({
      status: UNKNOWN,
      proven: false,
      reason: "READER_THREW",
      referee: "",
      seconds: null,
      code: null,
      raw: "",
      durationText: "",
      accepted: null,
    });
    return { phase: "SETTLED", accepted: null };
  }
  if (accepted !== true) {
    finish({
      status: UNKNOWN,
      proven: false,
      reason: "CALL_REJECTED",
      referee: "",
      seconds: null,
      code: null,
      raw: "",
      durationText: "",
      accepted: accepted,
    });
    return { phase: "SETTLED", accepted: false };
  }
  if (settled) {
    return { phase: "SETTLED", accepted: true };
  }
  return { phase: "PENDING", accepted: true };
}

export function readSportDuration(invoke) {
  let reading = null;
  const opened = openSportRead(invoke, function (result) {
    reading = result;
  });
  if (opened.phase === "PENDING") {
    return { status: UNKNOWN, proven: false, reason: "CALLBACK_PENDING", referee: "", seconds: null };
  }
  return reading || { status: UNKNOWN, proven: false, reason: "NO_READER", referee: "", seconds: null };
}

export function beginPending(state, accepted) {
  return copyProbe(state, {
    phase: "PENDING",
    accepted: accepted,
    reason: "CALLBACK_PENDING",
    status: UNKNOWN,
    code: null,
    raw: "",
    durationText: "",
    referee: "",
  });
}

export function markStillPending(state) {
  if (state.phase !== "PENDING") {
    return state;
  }
  return copyProbe(state, { reason: "NO_CALLBACK_10S", status: UNKNOWN });
}

export function admitSource(kind) {
  const reasons = {
    SPORT_DISPLAY_STRING: "DISPLAY_STRING_NOT_ELAPSED",
    WORKOUT_HISTORY_SECONDS: "HISTORY_RECORD_NOT_LIVE",
    SYS_TIMER_CALLBACK: "CALLBACK_NOT_DURATION",
    UTC_WALL_CLOCK: "WALL_CLOCK_NOT_ELAPSED",
    SYSTEM_APP_JUMP: "LAUNCH_NOT_A_READING",
  };
  return {
    status: UNKNOWN,
    proven: false,
    reason: reasons[kind] || "NO_NATIVE_ELAPSED_SOURCE",
  };
}

function assertedKey(value, depth) {
  if (value == null || typeof value !== "object" || depth > 6) {
    return "";
  }
  const keys = Object.keys(value);
  for (let i = 0; i < keys.length; i += 1) {
    if (ASSERTED_KEYS.indexOf(keys[i]) >= 0) {
      return keys[i];
    }
  }
  const nested = Array.isArray(value) ? value : keys.map(function (key) { return value[key]; });
  for (let i = 0; i < nested.length; i += 1) {
    const found = assertedKey(nested[i], depth + 1);
    if (found) {
      return found;
    }
  }
  return "";
}

function reject(reason, extra) {
  const result = { status: UNKNOWN, proven: false, reason: reason };
  if (extra) {
    const keys = Object.keys(extra);
    for (let i = 0; i < keys.length; i += 1) {
      result[keys[i]] = extra[keys[i]];
    }
  }
  return result;
}

function inspectRead(row) {
  if (!row || row.api !== "getSportData" || row.type !== "duration") {
    return reject("API_IDENTITY");
  }
  if (row.permission !== 2) {
    return reject("PERMISSION", { permission: row.permission == null ? null : row.permission });
  }
  if (row.accepted !== true) {
    return reject("CALL_REJECTED");
  }
  if (typeof row.code !== "number" || !isFinite(row.code)) {
    return reject("SPORT_SHAPE");
  }
  if (row.code !== 0) {
    return reject("SPORT_CODE", { callbackCode: row.code });
  }
  if (typeof row.raw !== "string") {
    return reject("RAW_MISSING");
  }
  const parsed = parseSportPayload(row.raw);
  if (!parsed.ok) {
    return reject(parsed.reason);
  }
  return { ok: true, seconds: parsed.seconds, referee: parsed.referee };
}

function readsOf(report, kind) {
  const rows = Array.isArray(report.reads) ? report.reads : [];
  const found = [];
  for (let i = 0; i < rows.length; i += 1) {
    if (rows[i] && rows[i].kind === kind) {
      found.push(rows[i]);
    }
  }
  return found;
}

export function reviewHardware(report) {
  if (!report || typeof report !== "object") {
    return reject("NO_PHYSICAL_REPORT");
  }
  const asserted = assertedKey(report, 0);
  if (asserted) {
    return reject("ASSERTED_FIELD", { field: asserted });
  }
  if (BIP6_SOURCES.indexOf(report.deviceSource) < 0) {
    return reject("DEVICE_SOURCE");
  }
  if (report.probe !== PROBE_ID || report.version !== PROBE_VERSION) {
    return reject("PROBE_IDENTITY");
  }
  if (!Array.isArray(report.reads) || report.reads.length === 0) {
    return reject("NO_READS");
  }
  const seenSleep = {};
  let worst = 0;
  for (let i = 0; i < report.reads.length; i += 1) {
    const row = report.reads[i];
    const inspected = inspectRead(row);
    if (!inspected.ok) {
      return inspected;
    }
    if (row.kind === "sleep") {
      if (REQUIRED_SLEEP_SECONDS.indexOf(row.sleepSeconds) < 0) {
        return reject("INTERVAL_MISSING");
      }
      if (seenSleep[row.sleepSeconds]) {
        return reject("DUPLICATE_INTERVAL");
      }
      seenSleep[row.sleepSeconds] = true;
      if (typeof row.stopwatchSeconds !== "number" || !isFinite(row.stopwatchSeconds) || row.stopwatchSeconds < 0) {
        return reject("STOPWATCH");
      }
      const errorMs = Math.round(Math.abs(inspected.seconds - row.stopwatchSeconds) * 1000);
      if (errorMs > worst) {
        worst = errorMs;
      }
    }
  }
  for (let i = 0; i < REQUIRED_SLEEP_SECONDS.length; i += 1) {
    if (!seenSleep[REQUIRED_SLEEP_SECONDS[i]]) {
      return reject("INTERVAL_MISSING");
    }
  }
  if (readsOf(report, "wake").length < 3) {
    return reject("WAKE_MISSING");
  }
  if (readsOf(report, "reopen").length < 1) {
    return reject("REOPEN_MISSING");
  }
  if (readsOf(report, "bluetooth").length < 1) {
    return reject("BLUETOOTH_MISSING");
  }
  if (readsOf(report, "pause").length < 1 || readsOf(report, "resume").length < 1) {
    return reject("PAUSE_MISSING");
  }
  if (worst > ERROR_LIMIT_MS) {
    return reject("ERROR_OVER_LIMIT", { worstAbsErrorMs: worst });
  }
  return { status: PROVEN, proven: true, reason: "PHYSICAL_WITHIN_1S", worstAbsErrorMs: worst };
}

export function timingMatrix() {
  return [
    {
      capability: "live_sport_duration_string",
      state: "DOCUMENTED",
      availability: "EXTENSION_CONTEXT",
      source: DOCUMENTED.sport,
      note: "getSportData type duration returns a display string such as 1:15:15. The call is not an elapsed-time type.",
    },
    {
      capability: "workout_extension_on_bip6",
      state: "DOCUMENTED",
      availability: "UNAVAILABLE",
      source: DOCUMENTED.extension,
      note: "The intro names six devices. Amazfit Bip 6 is not among them.",
    },
    {
      capability: "extension_pause_suspends_timers",
      state: "DOCUMENTED",
      availability: "PAUSES_JS_TIMERS",
      source: DOCUMENTED.extensionQuick,
      note: "Losing focus enters Pause. Registered timers pause and callbacks do not run.",
    },
    {
      capability: "sport_data_duration_widget",
      state: "DOCUMENTED",
      availability: "DISPLAY_ONLY",
      source: DOCUMENTED.sportWidget,
      note: "DURATION_NET is drawn by the widget. The widget does not return a number to script.",
    },
    {
      capability: "workout_sensor_live_timer",
      state: "DOCUMENTED",
      availability: "UNAVAILABLE",
      source: DOCUMENTED.workout,
      note: "Workout exposes status, history, heart-rate zones, and track navigation. It has no start, pause, or live duration method.",
    },
    {
      capability: "workout_history_duration_seconds",
      state: "DOCUMENTED",
      availability: "HISTORY_ONLY",
      source: DOCUMENTED.workout,
      note: "getHistory returns startTime and whole seconds for a stored record. That is not a running stopwatch.",
    },
    {
      capability: "system_stopwatch_and_sport_apps",
      state: "DOCUMENTED",
      availability: "LAUNCH_ONLY",
      source: DOCUMENTED.systemApp,
      note: "checkSystemApp can ask whether Stopwatch, Workout, or Workout History can be opened. The function returns void.",
    },
    {
      capability: "utc_wall_clock",
      state: "DOCUMENTED",
      availability: "NOT_ELAPSED",
      source: DOCUMENTED.time,
      note: "Time.getTime is a UTC millisecond timestamp. The Time sensor has no monotonic or boot-time method.",
    },
    {
      capability: "create_sys_timer",
      state: "DOCUMENTED",
      availability: "CALLBACK_ONLY",
      source: DOCUMENTED.sysTimer,
      note: "createSysTimer schedules a callback in an App Service regardless of screen state. The return value is a timer id, not elapsed duration.",
    },
    {
      capability: "standalone_bip6_getSportData_duration",
      state: "HARDWARE_NOT_TESTED",
      availability: "PROBE_BUILT",
      source: DOCUMENTED.sport,
      note: "DUR-001 calls getSportData from a standalone Device App. No watch callback has been recorded.",
    },
  ];
}
