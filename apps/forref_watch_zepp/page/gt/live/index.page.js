import { back } from "@zos/router";
import { createTimer, stopTimer } from "@zos/timer";
import { logDevice, bindBack, clear, paintBase, textAt, button } from "../../../utils/chrome";
import { layoutClock } from "../../../utils/geometry";
import { t } from "../../../utils/text";
import { state } from "../../../utils/state";
import {
  applyIntent,
  sample,
  present,
  displayText,
  trace,
  loadSession,
  commitSession,
  Trust,
} from "../../../utils/match_clock";
import { deviceNow, deviceAdapter } from "../../../utils/clock_device";

let timerId = null;
let metrics = null;
let widgets = null;
let paintKey = "";
let banner = "";

const ACTION_TEXT = {
  KICK_OFF: "kickOff",
  PAUSE: "pause",
  RESUME: "resume",
  END_FIRST_HALF: "endFirst",
  START_SECOND_HALF: "startSecond",
  FULL_TIME: "fullTime",
  CONTINUE_FROM_LAST: "continueClock",
};

function bag() {
  const data = state();
  if (!data.clockEpoch) {
    data.clockEpoch = "missing";
  }
  return data;
}

function current() {
  return bag().clockLive.session;
}

function remember(session) {
  const data = bag();
  data.clockLive = { epoch: data.clockEpoch, session: session };
}

function boot() {
  const data = bag();
  if (data.clockLive && data.clockLive.epoch === data.clockEpoch && data.clockLive.session) {
    return;
  }
  const loaded = loadSession(deviceAdapter(), data.clockEpoch);
  data.clockLive = { epoch: data.clockEpoch, session: loaded.session };
  console.log(trace("LOAD", data.clockLive.session.phase, loaded.session, deviceNow()));
}

function viewNow() {
  return present(current(), deviceNow());
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
  const period = view.phase.indexOf("SECOND") === 0 ? t("period2") : t("period1");
  const motion = view.running ? t("running") : t("paused");
  return period + " · " + motion;
}

function detailLabel(view) {
  if (banner) {
    return banner;
  }
  if (view.unverified) {
    return t("recoveryRequired") + " · " + t("lastKnown") + " " + view.lastKnown;
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
  if (action === "END_FIRST_HALF" || action === "FULL_TIME") {
    return 0x6e2b2b;
  }
  if (action === "PAUSE") {
    return 0x6e5418;
  }
  if (action === "KICK_OFF" || action === "START_SECOND_HALF" || action === "RESUME") {
    return 0x0d5c45;
  }
  return 0x0b2d5b;
}

function paintAll(named) {
  const view = viewNow();
  const key = view.phase + "|" + view.actions.join(",") + "|" + (view.unverified ? "U" : "K");
  paintKey = key;
  clear();
  paintBase(metrics);
  const laid = layoutClock(metrics, view.actions.length > 1 ? 2 : 1);
  const status = textAt(laid.status.x, laid.status.y, laid.status.w, laid.status.h, statusLabel(view), 22, 0x3fc3be);
  const digits = textAt(
    laid.time.x,
    laid.time.y,
    laid.time.w,
    laid.time.h,
    digitLabel(view),
    view.added ? 36 : 52,
    0xffffff
  );
  const score = textAt(laid.score.x, laid.score.y, laid.score.w, laid.score.h, detailLabel(view), 16, 0xc4a35a);
  const primary = view.actions[0];
  if (primary && laid.primary) {
    button(
      laid.primary.x,
      laid.primary.y,
      laid.primary.w,
      laid.primary.h,
      t(ACTION_TEXT[primary]),
      () => onAction(primary),
      fillFor(primary),
      named ? "clock-" + primary : "",
      metrics
    );
  }
  const secondary = view.actions[1];
  if (secondary && laid.secondary) {
    button(
      laid.secondary.x,
      laid.secondary.y,
      laid.secondary.w,
      laid.secondary.h,
      t(ACTION_TEXT[secondary]),
      () => onAction(secondary),
      fillFor(secondary),
      named ? "clock-" + secondary : "",
      metrics
    );
  }
  button(
    laid.back.x,
    laid.back.y,
    laid.back.w,
    laid.back.h,
    t("back"),
    () => back(),
    0x12324d,
    named ? "clock-back" : "",
    metrics
  );
  widgets = { status: status, digits: digits, score: score };
}

function repaint(structural) {
  const view = viewNow();
  const key = view.phase + "|" + view.actions.join(",") + "|" + (view.unverified ? "U" : "K");
  if (structural || key !== paintKey || !widgets) {
    paintAll(true);
    return;
  }
  paintAll(false);
}

function finishCommit(before, result, utc) {
  console.log(trace(result.ok ? result.reason : "REJECT", before.phase, result.session, utc));
  if (!result.ok) {
    if (result.duplicate) {
      banner = t("alreadyApplied");
    } else if (result.reason === "ILLEGAL" || result.reason === "UNVERIFIED") {
      banner = t("notApplied");
    } else {
      banner = t("timeUnverified");
    }
    if (result.session !== before && result.session.trust === Trust.UNVERIFIED) {
      const saved = commitSession(deviceAdapter(), result.session);
      if (!saved.ok) {
        banner = t("notCompleted");
      }
      remember(result.session);
    }
    repaint(true);
    return;
  }
  const saved = commitSession(deviceAdapter(), result.session);
  if (!saved.ok) {
    banner = t("notCompleted");
    console.log(trace("READBACK_FAIL", before.phase, before, utc));
    repaint(true);
    return;
  }
  banner = "";
  remember(result.session);
  repaint(true);
}

function onAction(intent) {
  const before = current();
  const utc = deviceNow();
  if (utc == null) {
    const failed = sample(before, { utcMillis: null, epoch: bag().clockEpoch, discontinuity: "CLOCK_UNAVAILABLE" });
    remember(failed.session);
    banner = t("timeUnverified");
    console.log(trace("CLOCK_UNAVAILABLE", before.phase, failed.session, 0));
    repaint(true);
    return;
  }
  const result = applyIntent(before, intent, {
    utcMillis: utc,
    epoch: bag().clockEpoch,
    intentId: intent + "-" + utc + "-" + before.seq,
  });
  finishCommit(before, result, utc);
}

function onTick() {
  const before = current();
  const utc = deviceNow();
  if (!before) {
    return;
  }
  if (utc == null) {
    const failed = sample(before, { utcMillis: null, epoch: bag().clockEpoch });
    remember(failed.session);
    console.log(trace("CLOCK_UNAVAILABLE", before.phase, failed.session, 0));
    repaint(true);
    return;
  }
  const sampled = sample(before, { utcMillis: utc, epoch: bag().clockEpoch });
  remember(sampled.session);
  if (sampled.event === "UNVERIFIED") {
    const saved = commitSession(deviceAdapter(), sampled.session);
    if (!saved.ok) {
      banner = t("notCompleted");
    }
    console.log(trace("UNVERIFIED", before.phase, sampled.session, utc));
    repaint(true);
    return;
  }
  if (sampled.event === "TICK") {
    console.log(trace("TICK", before.phase, sampled.session, utc));
  }
  repaint(false);
}

function ensureTimer() {
  if (timerId != null) {
    return;
  }
  timerId = createTimer(1000, 1000, () => {
    onTick();
  });
  console.log("FORREF_CLOCK001 TIMER|createTimer!");
}

function stopClockTimer() {
  if (timerId == null) {
    return;
  }
  stopTimer(timerId);
  timerId = null;
}

Page({
  onInit() {
    console.log("FORREF_PAGE live clock");
  },
  build() {
    metrics = logDevice("live");
    bindBack(false);
    boot();
    paintAll(true);
    stopClockTimer();
    ensureTimer();
  },
  onDestroy() {
    stopClockTimer();
    clear();
    widgets = null;
    paintKey = "";
    console.log("FORREF_PAGE live onDestroy");
  },
});
