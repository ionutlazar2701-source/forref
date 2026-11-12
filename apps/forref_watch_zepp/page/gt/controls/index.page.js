import { push, back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";
import { displayText } from "../../../utils/match_clock";
import { bootLive, viewNow, performIntent } from "../../../utils/live_session";

let armAbandon = false;
let banner = "";

const ACTION_TEXT = {
  END_FIRST_HALF: "endFirst",
  FULL_TIME: "fullTime",
  SUSPEND_GAME: "suspendGame",
  ABANDON_GAME: "abandonGame",
  RESUME_GAME: "resumeGame",
  START_SECOND_HALF: "startSecond",
  PAUSE: "pause",
  RESUME: "resume",
  KICK_OFF: "kickOff",
  CONTINUE_FROM_LAST: "continueClock",
};

function fillFor(action) {
  if (action === "END_FIRST_HALF" || action === "FULL_TIME" || action === "ABANDON_GAME") {
    return 0x6e2430;
  }
  if (action === "SUSPEND_GAME") {
    return 0x6e5418;
  }
  return 0x0b2d5b;
}

function statusLine(view) {
  const digits = view.unverified ? "——:——" : displayText(view);
  let label = t("clockReady");
  if (view.unverified) {
    label = t("timeUnverified");
  } else if (view.phase === "HALF_TIME") {
    label = t("halfTime");
  } else if (view.phase === "FULL_TIME") {
    label = t("fullTimeState");
  } else if (view.phase === "ABANDONED") {
    label = t("abandoned");
  } else if (view.phase.indexOf("SUSPENDED") >= 0) {
    label = t("matchSuspended");
  } else if (view.phase !== "READY") {
    const period = view.phase.indexOf("SECOND") === 0 ? t("period2") : t("period1");
    const motion = view.phase.indexOf("PAUSED") >= 0 ? t("clockPaused") : t("running");
    label = period + " · " + motion;
  }
  return label + " · " + digits + (banner ? " · " + banner : "");
}

function paint(metrics) {
  const view = viewNow();
  const rows = [{ label: statusLine(view), color: view.unverified ? 0xc4a35a : 0xffffff }];
  const controls = view.actions.slice(1);
  controls.forEach((action) => {
    const label = action === "ABANDON_GAME" && armAbandon ? t("confirmAbandon") : t(ACTION_TEXT[action]);
    rows.push({
      label: label,
      action: () => run(metrics, action),
      fill: fillFor(action),
      name: "ctrl-" + action,
    });
  });
  rows.push({
    label: t("display"),
    action: () => push({ url: "page/gt/display/index.page" }),
    name: "ctrl-display",
  });
  rows.push({
    label: t("backToLive"),
    action: () => back(),
    name: "ctrl-back",
  });
  stack(metrics, t("matchControls"), rows);
  console.log("FORREF_LIVE002 CTRL|" + view.phase + "|" + controls.join(",") + "!");
}

function run(metrics, intent) {
  const confirmed = intent === "ABANDON_GAME" && armAbandon;
  const result = performIntent(intent, { confirmed: confirmed });
  if (result.reason === "CONFIRM_REQUIRED") {
    armAbandon = true;
    banner = t("confirmAbandon");
    paint(metrics);
    return;
  }
  armAbandon = false;
  banner = result.ok ? "" : t("notApplied");
  if (result.ok) {
    back();
    return;
  }
  paint(metrics);
}

Page({
  build() {
    const metrics = logDevice("controls");
    bindBack(false);
    bootLive();
    paint(metrics);
  },
  onDestroy() {
    console.log("FORREF_PAGE controls onDestroy");
  },
});
