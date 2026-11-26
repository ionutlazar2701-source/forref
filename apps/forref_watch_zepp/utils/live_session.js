// One prototype session for Live A and Live C. Not a second clock and not Match Memory.
import { state } from "./state";
import {
  applyIntent,
  sample,
  present,
  trace,
  commitSession,
  liveFrame,
  Trust,
  isUtcSegment,
  noteDiscontinuity,
} from "./match_clock";
import { commitSegment, loadLiveClock } from "./clock_segment";
import { deviceNow, deviceAdapter, deviceScreen, segmentAdapter, watchPhoneTime } from "./clock_device";
import { commitForward, preferObserved, readStoredSession } from "./clock_continuity";
import { clockHostSnapshot, syncClockService } from "./clock_service_bind";
import { readWitness, writeWitness } from "./clock_witness_device";
import {
  formatWitness,
  noteAdmit,
  noteForegroundCheckpoint,
  noteHost,
  noteRecover,
} from "./clock_sleep_witness";
import { BUILD_NAME, bootLine } from "./build_stamp";
import { noteClockCommit } from "./telemetry";

export const BUILD = BUILD_NAME;

let bootLogged = false;
let lastScreen = "";
let phoneArmed = false;

function bag() {
  const data = state();
  if (!data.clockEpoch) {
    data.clockEpoch = "missing";
  }
  return data;
}

export function currentSession() {
  return bag().clockLive.session;
}

export function rememberSession(session) {
  const data = bag();
  data.clockLive = { epoch: data.clockEpoch, session: session };
}

export function bootLive() {
  const data = bag();
  if (!bootLogged) {
    bootLogged = true;
    console.log(bootLine());
  }
  if (data.clockLive && data.clockLive.epoch === data.clockEpoch && data.clockLive.session) {
    return data.clockLive.session;
  }
  const now = deviceNow();
  const loaded = loadLiveClock(segmentAdapter(), deviceAdapter(), data.clockEpoch, now);
  if (loaded.reason.indexOf("MIGRATED_") === 0) {
    commitSegment(segmentAdapter(), loaded.session);
  }
  data.clockLive = { epoch: data.clockEpoch, session: loaded.session };
  armPhone();
  const last = loaded.session.lastUtc == null ? "" : loaded.session.lastUtc;
  const step = now == null || loaded.session.lastUtc == null ? "" : now - loaded.session.lastUtc;
  console.log(trace("LOAD", data.clockLive.session.phase, loaded.session, now));
  console.log(
    "FORREF_CLOCK_SLEEP recover=" +
      loaded.reason +
      " phase=" +
      loaded.session.phase +
      " trust=" +
      loaded.session.trust +
      " last=" +
      last +
      " step=" +
      step +
      " notice=" +
      (loaded.session.notice || "") +
      " screen=" +
      deviceScreen()
  );
  noteClockCommit(loaded.session, data.clockEpoch, { boot: true });
  recordWitness(function (witness) {
    return noteRecover(witness, loaded.reason);
  }, now);
  armClockService(loaded.session);
  return data.clockLive.session;
}

function recordWitness(change, utc) {
  try {
    const witness = change(readWitness());
    writeWitness(witness);
    console.log("FORREF_CLOCK_SLEEP witness=" + formatWitness(witness, utc));
  } catch (err) {
    console.log("FORREF_CLOCK_SLEEP witness=fail");
  }
}

function armClockService(session) {
  if (session && session.engine === "utc_segment") {
    return;
  }
  try {
    syncClockService(session);
  } catch (err) {
    console.log("FORREF_CLOCK_SLEEP service=unavailable");
  }
}

function armPhone() {
  if (phoneArmed) {
    return;
  }
  phoneArmed = true;
  watchPhoneTime(function () {
    const before = currentSession();
    if (!before || before.engine !== "utc_segment") {
      return;
    }
    const result = noteDiscontinuity(before, deviceNow(), "PHONE_TIME_SETTING");
    if (!result.session || result.reason === "HELD") {
      return;
    }
    rememberSession(result.session);
    const saved = commitSegment(segmentAdapter(), result.session);
    console.log("FORREF_CLOCK004 phone-time reason=" + result.reason + " persist=" + saved.reason);
  });
}

function persistClock(session) {
  if (isUtcSegment(session)) {
    return commitSegment(segmentAdapter(), session);
  }
  return commitSession(deviceAdapter(), session);
}

function observedBase(memory, utc) {
  if (utc == null || isUtcSegment(memory)) {
    return memory;
  }
  return preferObserved(memory, readStoredSession(deviceAdapter()), utc) || memory;
}

export function viewNow() {
  const session = currentSession();
  if (session && isUtcSegment(session)) {
    const frame = liveFrame(session, deviceNow(), bag().clockEpoch);
    if (!frame.admitted && frame.session && frame.session.trust === Trust.UNVERIFIED) {
      rememberSession(frame.session);
      commitSegment(segmentAdapter(), frame.session);
    }
    return frame.view;
  }
  return present(session, session && session.lastUtc);
}

function admitObserved(before, utc, epoch, source) {
  const frame = liveFrame(observedBase(before, utc), utc, epoch);
  rememberSession(frame.session);
  let saved = { ok: true, reason: "HELD" };
  let commitMs = 0;
  if (!frame.admitted || frame.reason === "TICK") {
    const commitStarted = Date.now();
    saved = isUtcSegment(frame.session) ? commitSegment(segmentAdapter(), frame.session) : commitForward(deviceAdapter(), frame.session);
    commitMs = Date.now() - commitStarted;
    if ((saved.reason === "KEPT_NEWER" || saved.reason === "KEPT_HOLD") && saved.session) {
      rememberSession(saved.session);
    } else if (!frame.admitted && saved.ok) {
      noteClockCommit(frame.session, epoch);
      console.log(trace("UNVERIFIED", before.phase, frame.session, utc));
    } else if (!saved.ok) {
      console.log("FORREF_CLOCK_FG src=" + source + " persist=fail");
      if (!frame.admitted) {
        noteClockCommit(frame.session, epoch);
        console.log(trace("UNVERIFIED", before.phase, frame.session, utc));
      }
    }
  }
  const shown = frame.session && frame.session.lastUtc ? frame.session.lastUtc : 0;
  const anchor = before && before.lastUtc != null ? before.lastUtc : null;
  const step = anchor == null ? "" : utc - anchor;
  const screen = deviceScreen();
  if (screen !== lastScreen) {
    console.log(
      "FORREF_CLOCK_SLEEP edge=" +
        screen +
        " from=" +
        (lastScreen || "none") +
        " utc=" +
        utc +
        " last=" +
        (anchor == null ? "" : anchor) +
        " trust=" +
        before.trust +
        " reason=" +
        frame.reason
    );
    lastScreen = screen;
  }
  console.log(
    "FORREF_CLOCK_FG src=" +
      source +
      " reason=" +
      frame.reason +
      " readback=" +
      saved.reason +
      " last=" +
      shown +
      " trust=" +
      frame.session.trust +
      " step=" +
      step +
      " screen=" +
      screen +
      " commitMs=" +
      commitMs
  );
  frame.view.commitMs = commitMs;
  armClockService(frame.session);
  // A healthy projection does not rewrite the witness file. That write is
  // synchronous flash IO on the 1-second callback and was stretching the tick.
  if (frame.reason !== "UTC_ASSUMED" && frame.reason !== "HELD") {
    recordWitness(function (witness) {
      let next = noteAdmit(noteHost(witness, clockHostSnapshot()), frame.reason);
      if (frame.reason === "TICK" && saved.ok) {
        next = noteForegroundCheckpoint(next, shown);
      }
      return next;
    }, utc);
  }
  return frame;
}

// Admission runs before any Live widgets are created for this frame.
export function prepareFrame() {
  const before = currentSession();
  const utc = deviceNow();
  const epoch = bag().clockEpoch;
  if (!before) {
    return null;
  }
  if (utc == null) {
    const failed = sample(before, { utcMillis: null, epoch: epoch, discontinuity: "CLOCK_UNAVAILABLE" });
    rememberSession(failed.session);
    persistClock(failed.session);
    noteClockCommit(failed.session, epoch);
    console.log(trace("CLOCK_UNAVAILABLE", before.phase, failed.session, 0));
    return present(failed.session, failed.session.lastUtc);
  }
  const frame = admitObserved(before, utc, epoch, "page");
  return frame.view;
}

export function sampleFromScheduler(source) {
  const before = currentSession();
  const utc = deviceNow();
  const epoch = bag().clockEpoch;
  if (!before) {
    console.log("FORREF_CLOCK_FG src=" + source + " reason=NO_SESSION");
    return null;
  }
  if (utc == null) {
    const failed = sample(before, { utcMillis: null, epoch: epoch, discontinuity: "CLOCK_UNAVAILABLE" });
    rememberSession(failed.session);
    persistClock(failed.session);
    noteClockCommit(failed.session, epoch);
    console.log("FORREF_CLOCK_FG src=" + source + " reason=CLOCK_UNAVAILABLE");
    return present(failed.session, failed.session.lastUtc);
  }
  return admitObserved(before, utc, epoch, source).view;
}

function observation(intent, session, extra) {
  return {
    utcMillis: deviceNow(),
    epoch: bag().clockEpoch,
    intentId: intent + "-" + deviceNow() + "-" + session.seq,
    confirmed: !!(extra && extra.confirmed),
  };
}

export function performIntent(intent, extra) {
  const before = currentSession();
  const utc = deviceNow();
  if (utc == null) {
    const failed = sample(before, { utcMillis: null, epoch: bag().clockEpoch, discontinuity: "CLOCK_UNAVAILABLE" });
    rememberSession(failed.session);
    console.log(trace("CLOCK_UNAVAILABLE", before.phase, failed.session, 0));
    return { ok: false, reason: "CLOCK_UNAVAILABLE", session: failed.session, before: before };
  }
  const chosen = observedBase(before, utc);
  const result = applyIntent(chosen, intent, observation(intent, chosen, extra));
  console.log(trace(result.ok ? result.reason : "REJECT", before.phase, result.session, utc));
  if (!result.ok) {
    if (result.session !== before && result.session.trust === Trust.UNVERIFIED) {
      persistClock(result.session);
      rememberSession(result.session);
      noteClockCommit(result.session, bag().clockEpoch);
    }
    return result;
  }
  const saved = persistClock(result.session);
  if (!saved.ok) {
    console.log(trace("READBACK_FAIL", before.phase, before, utc));
    return { ok: false, reason: "READBACK_FAIL", session: before, before: before };
  }
  rememberSession(result.session);
  noteClockCommit(result.session, bag().clockEpoch);
  armClockService(result.session);
  console.log(
    "FORREF_CLOCK_SLEEP intent=" +
      intent +
      " ok=true reason=" +
      result.reason +
      " phase=" +
      result.session.phase +
      " trust=" +
      result.session.trust
  );
  return result;
}

export function sampleTick() {
  return prepareFrame();
}

export function persistLive() {
  const session = currentSession();
  if (!session) {
    return { ok: false, reason: "NO_SESSION" };
  }
  const utc = deviceNow();
  const chosen = observedBase(session, utc);
  if (isUtcSegment(chosen)) {
    const saved = commitSegment(segmentAdapter(), chosen);
    console.log("FORREF_CLOCK001 PERSIST|" + saved.reason + "!");
    return saved;
  }
  const saved = commitForward(deviceAdapter(), chosen);
  rememberSession(saved.reason === "KEPT_NEWER" && saved.session ? saved.session : chosen);
  console.log("FORREF_CLOCK001 PERSIST|" + saved.reason + "!");
  return saved;
}
