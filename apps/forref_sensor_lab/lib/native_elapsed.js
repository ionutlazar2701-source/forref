// CLOCK-001 probe. A display string and a timer callback are not proven elapsed time.
// This module does not import Zepp, start a workout, or write Match Memory.

export const PROVEN = "PROVEN_TIME";
export const UNKNOWN = "TIME_UNKNOWN";
export const ERROR_LIMIT_MS = 1000;
export const REQUIRED_SLEEP_SECONDS = Object.freeze([30, 120, 600]);

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
});

export function sources() {
  return DOCUMENTED;
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

export function readSportDuration(invoke) {
  const unknown = { status: UNKNOWN, proven: false, reason: "NO_READER", referee: "", seconds: null };
  if (typeof invoke !== "function") {
    return unknown;
  }
  let callbackResult = null;
  let called = false;
  let accepted = false;
  try {
    accepted = invoke({ type: "duration" }, function (result) {
      called = true;
      callbackResult = result;
    });
  } catch (err) {
    return { status: UNKNOWN, proven: false, reason: "READER_THREW", referee: "", seconds: null };
  }
  if (accepted !== true) {
    return { status: UNKNOWN, proven: false, reason: "CALL_REJECTED", referee: "", seconds: null };
  }
  if (!called || !callbackResult || callbackResult.code !== 0) {
    return { status: UNKNOWN, proven: false, reason: "SPORT_CODE", referee: "", seconds: null };
  }
  const parsed = parseSportPayload(callbackResult.data);
  return {
    status: UNKNOWN,
    proven: false,
    reason: parsed.reason,
    referee: parsed.referee,
    seconds: parsed.seconds,
  };
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

function hasSleep(report, seconds) {
  const rows = report && Array.isArray(report.intervals) ? report.intervals : [];
  for (let i = 0; i < rows.length; i += 1) {
    if (rows[i] && rows[i].sleepSeconds === seconds && typeof rows[i].absErrorMs === "number") {
      return rows[i];
    }
  }
  return null;
}

export function reviewHardware(report) {
  const reject = function (reason) {
    return { status: UNKNOWN, proven: false, reason: reason };
  };
  if (!report || report.measured !== true || report.device !== "Amazfit Bip 6" || report.source !== "PHYSICAL_BIP6") {
    return reject("NO_PHYSICAL_REPORT");
  }
  if (report.javascriptTicksUsed !== false) {
    return reject("JAVASCRIPT_TICKS");
  }
  if (report.repeatedWakes !== true || report.reopen !== true || report.bluetoothDrop !== true || report.pauseResume !== true) {
    return reject("PROTOCOL_INCOMPLETE");
  }
  let worst = 0;
  for (let i = 0; i < REQUIRED_SLEEP_SECONDS.length; i += 1) {
    const row = hasSleep(report, REQUIRED_SLEEP_SECONDS[i]);
    if (!row) {
      return reject("INTERVAL_MISSING");
    }
    if (row.absErrorMs > worst) {
      worst = row.absErrorMs;
    }
  }
  if (worst > ERROR_LIMIT_MS) {
    return reject("ERROR_OVER_LIMIT");
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
      capability: "standalone_bip6_native_elapsed_after_sleep",
      state: "HARDWARE_PENDING",
      availability: "NO_SUPPORTED_PATH",
      source: DOCUMENTED.service,
      note: "No reviewed public API lets a standalone Bip 6 Device App read an OS elapsed timer after screen sleep without a JavaScript callback.",
    },
  ];
}
