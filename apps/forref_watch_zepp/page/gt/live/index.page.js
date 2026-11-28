import { push, back } from "@zos/router";
import { createTimer, stopTimer } from "@zos/timer";
import { logDevice, bindBack, clear, clearDigits, paintBase, textAt, updateText, button } from "../../../utils/chrome";
import { digitHoldKey, nextPaintDelay } from "../../../utils/display_cadence";
import { layoutLive, liveTelemetrySlot } from "../../../utils/geometry";
import { localeChoice, t } from "../../../utils/text";
import { formatTelemetryLine, gpsStatusKey, hrStatusKey, pulseTelemetry } from "../../../utils/telemetry";
import { ACCENT, TEXT_PRIMARY, TEXT_SECONDARY, TEXT_WARNING } from "../../../utils/theme";
import { state } from "../../../utils/state";
import { displayText } from "../../../utils/match_clock";
import { bootLive, prepareFrame, performIntent, persistLive } from "../../../utils/live_session";
import { deviceNow } from "../../../utils/clock_device";
import { readWitness } from "../../../utils/clock_witness_device";
import { formatWitness } from "../../../utils/clock_sleep_witness";
import { createAbandonArm } from "../../../utils/abandon_arm";

let timerId = null;
let metrics = null;
let banner = "";
let shell = null;
let digitHold = null;
let lastLogged = "";
const arm = createAbandonArm();

const ACTION_TEXT = {
  KICK_OFF: "kickOff",
  PAUSE: "pause",
  RESUME: "resume",
  END_FIRST_HALF: "endFirst",
  START_SECOND_HALF: "startSecond",
  FULL_TIME: "fullTime",
  CONTINUE_FROM_LAST: "continueClock",
  SUSPEND_GAME: "suspendGame",
  RESUME_GAME: "resumeGame",
  ABANDON_GAME: "abandonGame",
};

function mode() {
  return state().display === "C" ? "C" : "A";
}

function contextOf(view) {
  return mode() + "|" + view.phase;
}

function leave(reason, go) {
  const result = arm.disarm(reason);
  console.log("FORREF_LIVE002 ARM|disarm|" + reason + "|" + (result.disarmed ? "was-armed" : "open") + "!");
  if (go) {
    go();
  }
}

function statusLabel(view) {
  if (view.unverified) {
    return t("timeUnverified");
  }
  if (view.phase === "READY") {
    return t("clockReady");
  }
  if (view.phase === "HALF_TIME") {
    return t("halfTime");
  }
  if (view.phase === "FULL_TIME") {
    return t("fullTimeState");
  }
  if (view.phase === "ABANDONED") {
    return t("abandoned") + " · " + t("notFullTime");
  }
  if (view.phase.indexOf("SUSPENDED") >= 0) {
    return t("matchSuspended");
  }
  const period = view.phase.indexOf("SECOND") === 0 ? t("period2") : t("period1");
  if (view.phase.indexOf("PAUSED") >= 0) {
    return period + " · " + t("clockPaused");
  }
  return period + " · " + t("running");
}

function detailLabel(view) {
  if (banner) {
    return banner;
  }
  try {
    return formatWitness(readWitness(), deviceNow());
  } catch (err) {
    if (view.unverified) {
      return t("lastKnown") + " " + view.lastKnown;
    }
    return "";
  }
}

function digitLabel(view) {
  if (view.unverified) {
    return "——:——";
  }
  return displayText(view);
}

function fillFor(action) {
  if (action === "END_FIRST_HALF" || action === "FULL_TIME" || action === "ABANDON_GAME") {
    return "red";
  }
  if (action === "PAUSE" || action === "SUSPEND_GAME") {
    return "caution";
  }
  if (action === "KICK_OFF" || action === "START_SECOND_HALF" || action === "RESUME" || action === "RESUME_GAME") {
    return "primary";
  }
  return "navigation";
}

function shellKey(view, current) {
  return [
    current,
    view.phase,
    view.actions[0] || "",
    arm.armed() ? "armed" : "open",
    banner,
    view.unverified ? "u" : "p",
    view.added ? "a" : "n",
  ].join("|");
}

function telemetryLabel() {
  const reading = pulseTelemetry();
  const hr = reading.hrFresh ? t("hrValue") : t(hrStatusKey(reading.hrState));
  return formatTelemetryLine(reading, {
    lang: localeChoice().lang,
    prefix: t("distancePrefix"),
    none: t("distanceNone"),
    hrValue: t("hrValue"),
    hr: hr,
    gps: t(gpsStatusKey(reading.gpsState)),
  });
}

function paintDigits(view, lay, current, rebuild) {
  const digits = digitLabel(view);
  const timeH = current === "C" ? 36 : 48;
  let telemetry = "";
  let telemetryY = 0;
  let telemetryH = 0;
  let nextY = lay.timeY + timeH;
  try {
    const slot = liveTelemetrySlot(lay, current, timeH);
    if (slot) {
      telemetry = telemetryLabel();
      telemetryY = slot.y;
      telemetryH = slot.h;
      nextY = slot.y + slot.h;
    }
  } catch (err) {
    console.log("FORREF_TEL paint=KEPT");
  }
  const detail = detailLabel(view);
  const detailLimit = current === "C" ? lay.away.y : lay.home.y;
  const showDetail = !!(detail && nextY + 14 <= detailLimit);
  const spec = {
    key: digitHoldKey({
      mode: current,
      unverified: view.unverified,
      added: view.added,
      telemetry: telemetry !== "",
      detail: showDetail,
      phaseY: lay.phaseY,
      timeY: lay.timeY,
    }),
    timeH: timeH,
    status: statusLabel(view),
    statusColor: view.unverified ? TEXT_WARNING : ACCENT,
    digits: digits,
    digitSize: view.added ? 28 : current === "C" ? 32 : 40,
    telemetry: telemetry,
    telemetryY: telemetryY,
    telemetryH: telemetryH,
    detail: showDetail ? detail : "",
    detailY: nextY,
  };
  if (!rebuild && digitHold && digitHold.key === spec.key) {
    updateText(digitHold.status, spec.status, spec.statusColor);
    updateText(digitHold.time, spec.digits, TEXT_PRIMARY);
    if (digitHold.telemetry) {
      updateText(digitHold.telemetry, spec.telemetry, TEXT_SECONDARY);
    }
    if (digitHold.detail) {
      updateText(digitHold.detail, spec.detail, TEXT_WARNING);
    }
    return;
  }
  clearDigits();
  const statusNode = textAt(12, lay.phaseY, metrics.width - 24, 28, spec.status, 20, spec.statusColor, true);
  const timeNode = textAt(12, lay.timeY, metrics.width - 24, spec.timeH, spec.digits, spec.digitSize, TEXT_PRIMARY, true);
  const telemetryNode = spec.telemetry
    ? textAt(12, spec.telemetryY, metrics.width - 24, spec.telemetryH, spec.telemetry, 14, TEXT_SECONDARY, true)
    : null;
  const detailNode = spec.detail
    ? textAt(12, spec.detailY, metrics.width - 24, 14, spec.detail, 12, TEXT_WARNING, true)
    : null;
  digitHold = {
    key: spec.key,
    status: statusNode,
    time: timeNode,
    telemetry: telemetryNode,
    detail: detailNode,
  };
}

function logView(view, current) {
  const line =
    current + "|" + view.phase + "|" + digitLabel(view) + "|" + (view.unverified ? "UNVERIFIED" : view.trust);
  if (line === lastLogged) {
    return;
  }
  lastLogged = line;
  console.log("FORREF_LIVE002 VIEW|" + line + "!");
}

function paintShell(view, lay) {
  const primary = view.actions[0];
  button(lay.home.x, lay.home.y, lay.home.w, lay.home.h, t("homeScore"), () => openTeam("HOME"), "neutral", "live-home", metrics);
  button(lay.away.x, lay.away.y, lay.away.w, lay.away.h, t("awayScore"), () => openTeam("AWAY"), "neutral", "live-away", metrics);
  if (primary) {
    const label = primary === "ABANDON_GAME" && arm.armed() ? t("confirmAbandon") : t(ACTION_TEXT[primary]);
    button(lay.display.x, lay.display.y, lay.display.w, lay.display.h, label, () => onAction(primary), fillFor(primary), "live-" + primary, metrics);
  } else {
    button(lay.display.x, lay.display.y, lay.display.w, lay.display.h, t("back"), () => leave("back", () => back()), "navigation", "live-back", metrics);
  }
  button(
    lay.back.x,
    lay.back.y,
    lay.back.w,
    lay.back.h,
    t("matchControls"),
    () => leave("navigate", () => push({ url: "page/gt/controls/index.page" })),
    "navigation",
    "live-controls",
    metrics
  );
}

function openTeam(team) {
  state().team = team;
  console.log("FORREF_LIVE002 NAV team=" + team + " mode=" + mode() + "!");
  leave("navigate", () => push({ url: "page/gt/event/index.page", params: JSON.stringify({ team: team }) }));
}

function paintAll() {
  const view = prepareFrame();
  if (!view) {
    return;
  }
  arm.retain(contextOf(view));
  const current = mode();
  const lay = layoutLive(metrics, current);
  const key = shellKey(view, current);
  if (!shell || shell.key !== key) {
    clear();
    digitHold = null;
    paintBase(metrics);
    paintDigits(view, lay, current, true);
    paintShell(view, lay);
    shell = { key: key };
  } else {
    paintDigits(view, lay, current, false);
  }
  logView(view, current);
}

function onAction(intent) {
  const view = prepareFrame();
  const ctx = view ? contextOf(view) : mode();
  if (intent !== "ABANDON_GAME") {
    arm.disarm("other-intent");
  }
  const confirmed = intent === "ABANDON_GAME" && arm.confirmed(ctx);
  const result = performIntent(intent, { confirmed: confirmed });
  if (result.reason === "CONFIRM_REQUIRED") {
    arm.arm(ctx);
    banner = t("confirmAbandon");
    paintAll();
    return;
  }
  arm.disarm("resolved");
  if (!result.ok) {
    banner = result.reason === "DUPLICATE" ? t("alreadyApplied") : result.reason === "READBACK_FAIL" ? t("notCompleted") : t("notApplied");
    paintAll();
    return;
  }
  banner = "";
  paintAll();
}

function ensureTimer() {
  if (timerId != null) {
    return;
  }
  const delay = nextPaintDelay(deviceNow());
  timerId = createTimer(delay, 1000, () => {
    paintAll();
  });
  console.log("FORREF_LIVE002 TIMER|period=1000 delay=" + delay + "!");
}

function stopClockTimer() {
  if (timerId == null) {
    return;
  }
  stopTimer(timerId);
  timerId = null;
  console.log("FORREF_LIVE002 TIMER|stop!");
}

Page({
  onInit() {
    console.log("FORREF_PAGE live onInit");
  },
  build() {
    metrics = logDevice("live");
    bindBack(false);
    bootLive();
    shell = null;
    paintAll();
    stopClockTimer();
    ensureTimer();
  },
  onDestroy() {
    leave("exit");
    stopClockTimer();
    persistLive();
    shell = null;
    digitHold = null;
    clear();
    console.log("FORREF_PAGE live onDestroy");
  },
});
