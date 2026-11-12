import { push, back } from "@zos/router";
import { createTimer, stopTimer } from "@zos/timer";
import { logDevice, bindBack, clear, paintBase, textAt, button } from "../../../utils/chrome";
import { layoutLive } from "../../../utils/geometry";
import { t } from "../../../utils/text";
import { state } from "../../../utils/state";
import { displayText } from "../../../utils/match_clock";
import { bootLive, viewNow, performIntent, sampleTick } from "../../../utils/live_session";

let timerId = null;
let metrics = null;
let banner = "";
let armAbandon = false;

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
  return t("scoreUnavailable");
}

function digitLabel(view) {
  if (view.unverified) {
    return "——:——";
  }
  return displayText(view);
}

function fillFor(action) {
  if (action === "END_FIRST_HALF" || action === "FULL_TIME" || action === "ABANDON_GAME") {
    return 0x6e2430;
  }
  if (action === "PAUSE" || action === "SUSPEND_GAME") {
    return 0x6e5418;
  }
  if (action === "KICK_OFF" || action === "START_SECOND_HALF" || action === "RESUME" || action === "RESUME_GAME") {
    return 0x0d5c45;
  }
  return 0x0b2d5b;
}

function openTeam(team) {
  state().team = team;
  console.log("FORREF_LIVE002 NAV team=" + team + " mode=" + mode() + "!");
  push({ url: "page/gt/event/index.page", params: JSON.stringify({ team: team }) });
}

function paintAll() {
  const view = viewNow();
  const current = mode();
  const lay = layoutLive(metrics, current);
  clear();
  paintBase(metrics);
  textAt(12, lay.phaseY, metrics.width - 24, 28, statusLabel(view), 20, 0x3fc3be);
  const timeH = current === "C" ? 36 : 48;
  textAt(12, lay.timeY, metrics.width - 24, timeH, digitLabel(view), view.added ? 28 : current === "C" ? 32 : 40, 0xffffff);
  const detailY = lay.timeY + timeH;
  const detailLimit = current === "C" ? lay.away.y : lay.home.y;
  if (detailY + 18 <= detailLimit) {
    textAt(12, detailY, metrics.width - 24, 18, detailLabel(view), 14, 0xc4a35a);
  }
  button(lay.home.x, lay.home.y, lay.home.w, lay.home.h, t("home"), () => openTeam("HOME"), 0x0e4a48, "live-home", metrics);
  button(lay.away.x, lay.away.y, lay.away.w, lay.away.h, t("away"), () => openTeam("AWAY"), 0x1a3a5c, "live-away", metrics);
  const primary = view.actions[0];
  if (primary) {
    const label = primary === "ABANDON_GAME" && armAbandon ? t("confirmAbandon") : t(ACTION_TEXT[primary]);
    button(
      lay.display.x,
      lay.display.y,
      lay.display.w,
      lay.display.h,
      label,
      () => onAction(primary),
      fillFor(primary),
      "live-" + primary,
      metrics
    );
  } else {
    button(lay.display.x, lay.display.y, lay.display.w, lay.display.h, t("back"), () => back(), 0x12324d, "live-back", metrics);
  }
  button(
    lay.back.x,
    lay.back.y,
    lay.back.w,
    lay.back.h,
    t("matchControls"),
    () => push({ url: "page/gt/controls/index.page" }),
    0x0b2d5b,
    "live-controls",
    metrics
  );
  console.log(
    "FORREF_LIVE002 VIEW|" +
      current +
      "|" +
      view.phase +
      "|" +
      digitLabel(view) +
      "|" +
      (view.unverified ? "UNVERIFIED" : view.trust) +
      "!"
  );
}

function onAction(intent) {
  const confirmed = intent === "ABANDON_GAME" && armAbandon;
  const result = performIntent(intent, { confirmed: confirmed });
  if (result.reason === "CONFIRM_REQUIRED") {
    armAbandon = true;
    banner = t("confirmAbandon");
    paintAll();
    return;
  }
  armAbandon = false;
  if (!result.ok) {
    banner = result.reason === "DUPLICATE" ? t("alreadyApplied") : result.reason === "READBACK_FAIL" ? t("notCompleted") : t("notApplied");
    paintAll();
    return;
  }
  banner = "";
  paintAll();
}

function onTick() {
  const sampled = sampleTick();
  if (!sampled) {
    return;
  }
  if (sampled.event === "UNVERIFIED" || sampled.event === "CLOCK_UNAVAILABLE") {
    banner = t("timeUnverified");
  }
  paintAll();
}

function ensureTimer() {
  if (timerId != null) {
    return;
  }
  timerId = createTimer(1000, 1000, () => {
    onTick();
  });
  console.log("FORREF_LIVE002 TIMER|createTimer!");
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
    paintAll();
    stopClockTimer();
    ensureTimer();
  },
  onDestroy() {
    stopClockTimer();
    clear();
    console.log("FORREF_PAGE live onDestroy");
  },
});
