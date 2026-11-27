import { push, back } from "@zos/router";
import { O_APPEND, O_CREAT, O_WRONLY, closeSync, openSync, readFileSync, writeFileSync, writeSync } from "@zos/fs";
import { logDevice, bindBack, clear, clearDigits, paintBase, textAt, setWidgetText, button } from "../../../utils/chrome";
import { layoutLive, liveTelemetrySlot } from "../../../utils/geometry";
import { localeChoice, t } from "../../../utils/text";
import { formatTelemetryLine, gpsStatusKey, hrStatusKey, pulseTelemetry } from "../../../utils/telemetry";
import { ACCENT, TEXT_PRIMARY, TEXT_SECONDARY, TEXT_WARNING } from "../../../utils/theme";
import { state } from "../../../utils/state";
import { displayText } from "../../../utils/match_clock";
import { bootLive, prepareFrame, performIntent, persistLive } from "../../../utils/live_session";
import { bindLivePaint, restartForegroundClock } from "../../../utils/clock_foreground_bind";
import { deviceNow } from "../../../utils/clock_device";
import { readWitness } from "../../../utils/clock_witness_device";
import { formatWitness } from "../../../utils/clock_sleep_witness";
import { createAbandonArm } from "../../../utils/abandon_arm";
import { openLocalGoal } from "../../../utils/goal_capture";
import { invalidatePublishedLocalScore, localTestPresentation, localTestScore, publishLocalScore, readPublishedLocalScore } from "../../../utils/local_test_score";

let unbindPaint = null;
let metrics = null;
let banner = "";
let shell = null;
let digitCache = null;
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

function goalFs() {
  return {
    readFileSync: readFileSync,
    writeFileSync: writeFileSync,
    openSync: openSync,
    writeSync: writeSync,
    closeSync: closeSync,
    O_WRONLY: O_WRONLY,
    O_CREAT: O_CREAT,
    O_APPEND: O_APPEND,
  };
}

function restoreScore() {
  invalidatePublishedLocalScore();
  try {
    const opened = openLocalGoal(goalFs(), "");
    if (!opened.admitted.localCandidate) {
      publishLocalScore({ kind: "hidden", knownScore: false, home: null, away: null });
      console.log("FORREF_SCORE outcome=hidden reason=" + (opened.admitted.reason || ""));
      return;
    }
    if (!opened.ok || !opened.journal) {
      publishLocalScore({ kind: "unavailable", knownScore: false, home: null, away: null });
      console.log("FORREF_RECOVERY outcome=RECOVERY_REQUIRED reason=" + (opened.reason || "journal"));
      return;
    }
    const loaded = opened.journal.load();
    const score = localTestScore(loaded.entries, opened.admitted, loaded.status);
    publishLocalScore(score);
    console.log("FORREF_SCORE outcome=" + score.kind + " home=" + score.home + " away=" + score.away + " knownScore=0");
  } catch (err) {
    publishLocalScore({ kind: "unavailable", knownScore: false, home: null, away: null });
    console.log("FORREF_SCORE outcome=unavailable reason=read");
  }
}

function lineFits(lay, current) {
  const timeH = current === "C" ? 36 : 48;
  let nextY = lay.timeY + timeH;
  try {
    const slot = liveTelemetrySlot(lay, current, timeH);
    if (slot) nextY = slot.y + slot.h;
  } catch (err) {
    nextY = lay.timeY + timeH;
  }
  const limit = current === "C" ? lay.away.y : lay.home.y;
  return nextY + 14 <= limit;
}

function presentationFor(lay, current) {
  const preview = readPublishedLocalScore() || { kind: "hidden", knownScore: false, home: null, away: null };
  return localTestPresentation(preview, lineFits(lay, current), {
    homeScore: t("homeScore"),
    awayScore: t("awayScore"),
    home: t("home"),
    away: t("away"),
    conflict: t("scoreConflict"),
    localTest: t("localTest"),
  });
}

function shellKey(view, current, presentation) {
  const shown = presentation || { warning: "", home: "", away: "" };
  return [
    current,
    view.phase,
    view.actions[0] || "",
    arm.armed() ? "armed" : "open",
    banner,
    view.unverified ? "u" : "p",
    view.added ? "a" : "n",
    shown.warning,
    shown.home,
    shown.away,
  ].join("|");
}

function teamButtonLabel(side, presentation) {
  return side === "home" ? presentation.home : presentation.away;
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

function paintDigits(view, lay, current, presentation) {
  const started = Date.now();
  const timeH = current === "C" ? 36 : 48;
  const status = statusLabel(view);
  const digits = digitLabel(view);
  const key = [current, view.phase, view.unverified ? "u" : "p", view.added ? "a" : "n", banner ? "b" : "o", lay.timeY, lay.phaseY].join("|");
  if (digitCache && digitCache.key === key) {
    const timeOk = setWidgetText(digitCache.time, digits);
    const statusOk = setWidgetText(digitCache.status, status);
    if (timeOk && statusOk) {
      if (digitCache.telemetry) {
        setWidgetText(digitCache.telemetry, telemetryLabel());
      }
      return Date.now() - started;
    }
  }
  clearDigits();
  const statusNode = textAt(12, lay.phaseY, metrics.width - 24, 28, status, 20, view.unverified ? TEXT_WARNING : ACCENT, true);
  const timeNode = textAt(12, lay.timeY, metrics.width - 24, timeH, digits, view.added ? 28 : current === "C" ? 32 : 40, TEXT_PRIMARY, true);
  let nextY = lay.timeY + timeH;
  let telemetryNode = null;
  try {
    const slot = liveTelemetrySlot(lay, current, timeH);
    if (slot) {
      telemetryNode = textAt(12, slot.y, metrics.width - 24, slot.h, telemetryLabel(), 14, TEXT_SECONDARY, true);
      nextY = slot.y + slot.h;
    }
  } catch (err) {
    console.log("FORREF_TEL paint=KEPT");
  }
  const warning = presentation && presentation.warning ? presentation.warning : "";
  const detail = warning || detailLabel(view);
  const detailLimit = current === "C" ? lay.away.y : lay.home.y;
  if (detail && nextY + 14 <= detailLimit) {
    textAt(12, nextY, metrics.width - 24, 14, detail, 12, TEXT_WARNING, true);
  } else if (warning || (presentation && presentation.withheld)) {
    console.log("FORREF_SCORE outcome=visual-pending reason=no-slot");
  }
  digitCache = { key: key, status: statusNode, time: timeNode, telemetry: telemetryNode };
  return Date.now() - started;
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

function paintShell(view, lay, presentation) {
  const primary = view.actions[0];
  button(lay.home.x, lay.home.y, lay.home.w, lay.home.h, teamButtonLabel("home", presentation), () => openTeam("HOME"), "neutral", "live-home", metrics);
  button(lay.away.x, lay.away.y, lay.away.w, lay.away.h, teamButtonLabel("away", presentation), () => openTeam("AWAY"), "neutral", "live-away", metrics);
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

function paintAll(prepared) {
  const view = prepared || prepareFrame();
  if (!view) {
    return null;
  }
  arm.retain(contextOf(view));
  const current = mode();
  const lay = layoutLive(metrics, current);
  const presentation = presentationFor(lay, current);
  const key = shellKey(view, current, presentation);
  let paintMs = 0;
  if (!shell || shell.key !== key) {
    clear();
    digitCache = null;
    paintBase(metrics);
    paintMs = paintDigits(view, lay, current, presentation);
    paintShell(view, lay, presentation);
    shell = { key: key };
  } else {
    paintMs = paintDigits(view, lay, current, presentation);
  }
  logView(view, current);
  return { digits: digitLabel(view) || "", paintMs: paintMs };
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

Page({
  onInit() {
    console.log("FORREF_PAGE live onInit");
  },
  build() {
    metrics = logDevice("live");
    bindBack(false);
    bootLive();
    shell = null;
    restoreScore();
    if (unbindPaint) {
      unbindPaint();
    }
    unbindPaint = bindLivePaint(function (view) {
      return paintAll(view);
    });
    paintAll();
    console.log("FORREF_CLOCK_FG page=build");
    restartForegroundClock();
  },
  onDestroy() {
    leave("exit");
    if (unbindPaint) {
      unbindPaint();
      unbindPaint = null;
    }
    persistLive();
    shell = null;
    digitCache = null;
    clear();
    console.log("FORREF_PAGE live onDestroy");
  },
});
