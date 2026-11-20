import { push, back } from "@zos/router";
import { createTimer, stopTimer } from "@zos/timer";
import { onGesture, onKey, KEY_BACK, KEY_EVENT_CLICK, GESTURE_LEFT, GESTURE_RIGHT, GESTURE_UP, GESTURE_DOWN } from "@zos/interaction";
import { logDevice, clear, clearDigits, paintBase, textAt, button, marker } from "../../../utils/chrome";
import { layoutLive, liveTelemetrySlot, layoutStack } from "../../../utils/geometry";
import { localeChoice, t } from "../../../utils/text";
import { formatTelemetryLine, gpsStatusKey, hrStatusKey, pulseTelemetry } from "../../../utils/telemetry";
import { ACCENT, TEXT_PRIMARY, TEXT_SECONDARY, TEXT_WARNING } from "../../../utils/theme";
import { state } from "../../../utils/state";
import { displayText } from "../../../utils/match_clock";
import { bootLive, prepareFrame, performIntent, persistLive } from "../../../utils/live_session";
import { createAbandonArm } from "../../../utils/abandon_arm";
import { applyAuthorizedIntent } from "../../../utils/control_apply";
import {
  PAGE_CAUTIONS,
  PAGE_CONTROLS,
  PAGE_LIVE,
  arbitratePlatformGesture,
  backTarget,
  dotMarks,
  initialPage,
  transitionPage,
} from "../../../utils/live_carousel";
import { layoutDots, pageFits, stackLimit, teamSeparator } from "../../../utils/live_carousel_layout";

let timerId = null;
let metrics = null;
let banner = "";
let shell = null;
let lastLogged = "";
let pageIndex = initialPage();
const arm = createAbandonArm();
const GESTURE_CODES = {
  left: GESTURE_LEFT,
  right: GESTURE_RIGHT,
  up: GESTURE_UP,
  down: GESTURE_DOWN,
};

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

function actionContext(view) {
  if (pageIndex === PAGE_LIVE) {
    return mode() + "|" + view.phase;
  }
  return "carousel-" + pageIndex + "|" + view.phase;
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
  if (view.unverified) {
    return t("lastKnown") + " " + view.lastKnown;
  }
  return "";
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
    pageIndex,
    current,
    view.phase,
    (view.actions || []).join(","),
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

function paintDots() {
  const laid = layoutDots(metrics);
  const marks = dotMarks(pageIndex);
  for (let i = 0; i < laid.dots.length; i++) {
    const dot = laid.dots[i];
    if (!dot.ok) {
      continue;
    }
    marker(dot.x, dot.y, dot.w, dot.h, marks[i].active ? ACCENT : TEXT_SECONDARY);
  }
}

function paintDigits(view, lay, current) {
  clearDigits();
  const timeH = current === "C" ? 36 : 48;
  textAt(12, lay.phaseY, metrics.width - 24, 28, statusLabel(view), 20, view.unverified ? TEXT_WARNING : ACCENT, true);
  textAt(12, lay.timeY, metrics.width - 24, timeH, digitLabel(view), view.added ? 28 : current === "C" ? 32 : 40, TEXT_PRIMARY, true);
  let nextY = lay.timeY + timeH;
  try {
    const slot = liveTelemetrySlot(lay, current, timeH);
    if (slot) {
      textAt(12, slot.y, metrics.width - 24, slot.h, telemetryLabel(), 14, TEXT_SECONDARY, true);
      nextY = slot.y + slot.h;
    }
  } catch (err) {
    console.log("FORREF_TEL paint=KEPT");
  }
  const detail = detailLabel(view);
  const detailLimit = current === "C" ? lay.away.y : lay.home.y;
  if (detail && nextY + 18 <= detailLimit) {
    textAt(12, nextY, metrics.width - 24, 18, detail, 14, TEXT_WARNING, true);
  }
}

function logView(view, current) {
  const line =
    pageIndex + "|" + current + "|" + view.phase + "|" + digitLabel(view) + "|" + (view.unverified ? "UNVERIFIED" : view.trust);
  if (line === lastLogged) {
    return;
  }
  lastLogged = line;
  console.log("FORREF_NFV5 PAGE|" + line + "!");
}

function showPage(next) {
  const step = transitionPage(pageIndex, next);
  if (!step.changed || step.intents.length !== 0) {
    return;
  }
  pageIndex = step.index;
  leave("navigate");
  shell = null;
  lastLogged = "";
  paintAll();
}

function openControlsRoute() {
  leave("navigate", () => push({ url: "page/gt/controls/index.page" }));
}

function openCautionsRoute() {
  leave("navigate", () => push({ url: "page/gt/cautions/index.page" }));
}

function openControls() {
  if (!pageFits(metrics, 6)) {
    openControlsRoute();
    return;
  }
  showPage(PAGE_CONTROLS);
}

function openCautions() {
  if (!pageFits(metrics, 4)) {
    openCautionsRoute();
    return;
  }
  showPage(PAGE_CAUTIONS);
}

function paintShell(view, lay) {
  const rule = teamSeparator(lay.home, lay.away);
  if (rule) {
    marker(rule.x, rule.y, rule.w, rule.h, TEXT_SECONDARY);
  }
  button(lay.home.x, lay.home.y, lay.home.w, lay.home.h, t("homeScore"), () => openTeam("HOME"), "neutral", "live-home", metrics);
  button(lay.away.x, lay.away.y, lay.away.w, lay.away.h, t("awayScore"), () => openTeam("AWAY"), "neutral", "live-away", metrics);
  const primary = view.actions[0];
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
    () => openControls(),
    "navigation",
    "live-controls",
    metrics
  );
  paintDots();
}

function openTeam(team) {
  state().team = team;
  console.log("FORREF_LIVE002 NAV team=" + team + " mode=" + mode() + "!");
  leave("navigate", () => push({ url: "page/gt/event/index.page", params: JSON.stringify({ team: team }) }));
}

function controlRows(view) {
  const rows = [];
  const controls = view.actions.slice(1);
  controls.forEach((action) => {
    const label = action === "ABANDON_GAME" && arm.armed() ? t("confirmAbandon") : t(ACTION_TEXT[action]);
    rows.push({
      label: label,
      action: () => onAction(action),
      fill: fillFor(action),
      name: "nf-" + action,
    });
  });
  rows.push({
    label: t("display"),
    action: () => leave("navigate", () => push({ url: "page/gt/display/index.page" })),
    name: "nf-display",
  });
  rows.push({
    label: t("cautions"),
    action: () => openCautions(),
    name: "nf-cautions",
  });
  rows.push({
    label: t("backToLive"),
    action: () => showPage(PAGE_LIVE),
    name: "nf-live",
  });
  return rows;
}

function paintStacked(view, title, rows) {
  const key = shellKey(view, "S" + pageIndex);
  const laid = layoutStack(metrics, rows.length + 1, stackLimit(metrics));
  if (!shell || shell.key !== key) {
    clear();
    paintBase(metrics);
    const guide = laid.rows[0] || { x: metrics.pad, w: metrics.contentW };
    textAt(guide.x, laid.titleY, guide.w, laid.titleH, title, Math.round(metrics.width * 0.045), ACCENT);
    rows.forEach((row, index) => {
      const slot = laid.rows[index + 1];
      if (!slot) {
        return;
      }
      if (row.action) {
        button(slot.x, slot.y, slot.w, slot.h, row.label, row.action, row.fill, row.name, metrics);
      } else {
        textAt(slot.x, slot.y, slot.w, slot.h, row.label, Math.round(metrics.width * 0.034), row.color || TEXT_WARNING);
      }
    });
    paintDots();
    shell = { key: key, status: laid.rows[0] };
  }
  clearDigits();
  const slot = shell.status;
  if (slot) {
    textAt(
      slot.x,
      slot.y,
      slot.w,
      slot.h,
      statusLabel(view) + " · " + digitLabel(view),
      16,
      view.unverified ? TEXT_WARNING : TEXT_PRIMARY,
      true
    );
  }
}

function paintControlPage(view) {
  paintStacked(view, t("matchControls"), controlRows(view));
}

function paintCautionPage(view) {
  paintStacked(view, t("cautions"), [
    { label: t("cautionsBody"), color: TEXT_WARNING },
    { label: t("matchControls"), action: () => openControls(), name: "nf-controls" },
    { label: t("backToLive"), action: () => showPage(PAGE_LIVE), name: "nf-live" },
  ]);
}

function paintAll() {
  const view = prepareFrame();
  if (!view) {
    return;
  }
  arm.retain(actionContext(view));
  const current = mode();
  const lay = layoutLive(metrics, current);
  if (pageIndex === PAGE_CONTROLS) {
    paintControlPage(view);
    logView(view, current);
    return;
  }
  if (pageIndex === PAGE_CAUTIONS) {
    paintCautionPage(view);
    logView(view, current);
    return;
  }
  const key = shellKey(view, current);
  if (!shell || shell.key !== key) {
    clear();
    paintBase(metrics);
    paintDigits(view, lay, current);
    paintShell(view, lay);
    shell = { key: key };
  } else {
    paintDigits(view, lay, current);
  }
  logView(view, current);
}

function onAction(intent) {
  const view = prepareFrame();
  const ctx = view ? actionContext(view) : mode();
  const outcome = applyAuthorizedIntent(intent, arm, ctx, performIntent);
  if (outcome.state === "confirm") {
    banner = t("confirmAbandon");
    shell = null;
    paintAll();
    return;
  }
  if (outcome.state !== "applied") {
    const reason = outcome.result && outcome.result.reason;
    banner = reason === "DUPLICATE" ? t("alreadyApplied") : reason === "READBACK_FAIL" ? t("notCompleted") : t("notApplied");
    shell = null;
    paintAll();
    return;
  }
  banner = "";
  if (pageIndex !== PAGE_LIVE) {
    pageIndex = PAGE_LIVE;
    leave("navigate");
  }
  shell = null;
  paintAll();
}

function onPlatformGesture(event) {
  const decision = arbitratePlatformGesture(event, GESTURE_CODES, pageIndex);
  console.log(
    "FORREF_NFV5 GESTURE gate=" + decision.gate + " reason=" + decision.reason + " consume=" + decision.consume + "!"
  );
  if (decision.reason === "PAGE_BACK" && decision.intents.length === 0) {
    showPage(decision.index);
  }
  return decision.consume === true;
}

function onHardwareKey(key, event) {
  if (key !== KEY_BACK || event !== KEY_EVENT_CLICK) {
    return false;
  }
  const target = backTarget(pageIndex);
  if (!target.leave && target.intents.length === 0) {
    showPage(target.index);
    return true;
  }
  leave("back", () => back());
  return true;
}

function ensureTimer() {
  if (timerId != null) {
    return;
  }
  timerId = createTimer(1000, 1000, () => {
    paintAll();
  });
  console.log("FORREF_LIVE002 TIMER|paint!");
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
    pageIndex = initialPage();
    bootLive();
    shell = null;
    banner = "";
    try {
      onKey({ callback: onHardwareKey });
    } catch (err) {
      console.log("FORREF_NFV5 KEY=unavailable");
    }
    try {
      onGesture({ callback: onPlatformGesture });
    } catch (err) {
      console.log("FORREF_NFV5 GESTURE gate=BLOCKED reason=API_UNAVAILABLE!");
    }
    paintAll();
    stopClockTimer();
    ensureTimer();
  },
  onDestroy() {
    leave("exit");
    stopClockTimer();
    persistLive();
    shell = null;
    pageIndex = initialPage();
    clear();
    console.log("FORREF_PAGE live onDestroy");
  },
});
