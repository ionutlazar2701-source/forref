// CLOCK-002. The native Stopwatch binding is a watchface display, not a duration read.
// This module does not import Zepp and does not count seconds.

export const UNKNOWN = "TIME_UNKNOWN";
export const STOPWATCH_DIGITS = 2;

const DOCUMENTED = Object.freeze({
  dataType: "https://docs.zepp.com/docs/watchface/api/hmUI/widget/data_type/",
  textImg: "https://docs.zepp.com/docs/watchface/api/hmUI/widget/TEXT_IMG/",
  getProperty: "https://docs.zepp.com/docs/watchface/api/hmUI/getProperty/",
  deviceText: "https://docs.zepp.com/docs/reference/device-app-api/newAPI/ui/widget/TEXT/",
  launch: "https://docs.zepp.com/docs/reference/device-app-api/newAPI/router/launchApp/",
  check: "https://docs.zepp.com/docs/reference/device-app-api/newAPI/router/checkSystemApp/",
});

const WIDGET_KEYS = Object.freeze([
  "x", "y", "w", "h", "color", "align_h", "align_v", "text", "text_size",
  "font", "text_style", "line_space", "char_space", "MORE", "VISIBLE", "TEXT", "H",
]);

export function sources() {
  return DOCUMENTED;
}

export function classifyDataType(name) {
  if (name !== "STOP_WATCH") {
    return { surface: "NOT_STOPWATCH", readable: false, proven: false };
  }
  return {
    surface: "WATCHFACE",
    mode: "DISPLAY",
    digits: STOPWATCH_DIGITS,
    unit: "MINUTES_OR_SECONDS",
    readable: false,
    proven: false,
    reason: "TWO_DIGIT_DISPLAY",
  };
}

export function classifyGetProperty(key) {
  const known = WIDGET_KEYS.indexOf(key) >= 0;
  return {
    kind: known ? "WIDGET_CONFIGURATION" : "UNDOCUMENTED_PROPERTY",
    key: key,
    stopwatch: false,
    proven: false,
    reason: known ? "CONFIG_NOT_ELAPSED" : "NOT_A_DOCUMENTED_READ",
  };
}

export function classifyCall(name, returned, threw) {
  if (threw) {
    return { name: name, text: "throw", duration: null, proven: false, reason: "CALL_THREW" };
  }
  if (name !== "launchApp" && name !== "checkSystemApp") {
    return { name: name, text: "unsupported", duration: null, proven: false, reason: "NO_PUBLIC_CONTROL" };
  }
  if (returned === undefined) {
    return { name: name, text: "void", duration: null, proven: false, reason: "RETURNS_VOID" };
  }
  return {
    name: name,
    text: typeof returned,
    duration: null,
    proven: false,
    reason: "NOT_A_DURATION",
  };
}

export function admitDisplayedDigits(text) {
  return {
    status: UNKNOWN,
    proven: false,
    reason: "DISPLAY_NOT_ELAPSED",
    digits: typeof text === "string" ? text : "",
  };
}

export function stopwatchMatrix() {
  return [
    {
      capability: "data_type_STOP_WATCH",
      state: "DOCUMENTED",
      availability: "DISPLAY_ONLY",
      source: DOCUMENTED.dataType,
      note: "Watchface data type. Two digits, minutes or seconds. It is not a Device App value.",
    },
    {
      capability: "TEXT_IMG_type_binding",
      state: "DOCUMENTED",
      availability: "DISPLAY_ONLY",
      source: DOCUMENTED.textImg,
      note: "type draws the bound data. Setting text disables type. setProperty TEXT replaces the picture text.",
    },
    {
      capability: "getProperty",
      state: "DOCUMENTED",
      availability: "WIDGET_CONFIGURATION",
      source: DOCUMENTED.getProperty,
      note: "Returns widget properties such as position and size. The Device App TEXT list is layout, font, and the text the app set.",
    },
    {
      capability: "device_app_text_widget",
      state: "DOCUMENTED",
      availability: "NO_STOPWATCH_BINDING",
      source: DOCUMENTED.deviceText,
      note: "The Device App TEXT parameters have no data_type and no STOP_WATCH field.",
    },
    {
      capability: "launch_and_check_system_stopwatch",
      state: "DOCUMENTED",
      availability: "LAUNCH_ONLY",
      source: DOCUMENTED.launch,
      note: "SYSTEM_APP_STOPWATCH can be opened. launchApp and checkSystemApp return void. They do not start, pause, resume, reset, or return a duration.",
    },
    {
      capability: "start_pause_resume_reset",
      state: "DOCUMENTED",
      availability: "UNAVAILABLE",
      source: DOCUMENTED.launch,
      note: "No public Device App method controls the native Stopwatch.",
    },
    {
      capability: "read_elapsed_while_foreground",
      state: "DOCUMENTED",
      availability: "NO_PUBLIC_READ",
      source: DOCUMENTED.dataType,
      note: "No public call returns the running Stopwatch duration to a foreground Device App.",
    },
    {
      capability: "system_stopwatch_continues_behind_another_app",
      state: "PROVEN",
      availability: "SYSTEM_UI_ONLY",
      source: "founder Bip 6 observation",
      note: "The founder saw the native Stopwatch keep running while another app was open. No duration value was recorded.",
    },
    {
      capability: "running_blocks_other_apps",
      state: "PROVEN",
      availability: "SYSTEM_UI_ONLY",
      source: "founder Bip 6 observation",
      note: "The founder saw an active Running workout block other apps. Concurrent Running plus DUR-001 is not the experiment.",
    },
    {
      capability: "programmatic_read_after_sleep_or_reopen",
      state: "NOT_TESTED",
      availability: "NO_PUBLIC_READ",
      source: DOCUMENTED.dataType,
      note: "There is no read to repeat after sleep or reopen. The system Stopwatch screen itself was not timed in this repository.",
    },
  ];
}

export function initialScreen() {
  return {
    read: "NO_PUBLIC_READ",
    control: "LAUNCH_ONLY",
    binding: "WATCHFACE_2_DIGITS",
    check: "-",
    open: "-",
    status: UNKNOWN,
  };
}

export function applyCall(state, field, result) {
  const next = {
    read: state.read,
    control: state.control,
    binding: state.binding,
    check: state.check,
    open: state.open,
    status: UNKNOWN,
  };
  next[field] = result.text;
  return next;
}
