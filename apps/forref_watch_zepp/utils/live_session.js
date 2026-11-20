// One prototype session for Live A and Live C. Not a second clock and not Match Memory.
import { state } from "./state";
import {
  applyIntent,
  sample,
  present,
  trace,
  loadSession,
  commitSession,
  liveFrame,
  Trust,
} from "./match_clock";
import { deviceNow, deviceAdapter } from "./clock_device";
import { commitForward, preferObserved, readStoredSession } from "./clock_continuity";
import { syncClockService } from "./clock_service_bind";
import { BUILD_NAME, bootLine } from "./build_stamp";
import { noteClockCommit } from "./telemetry";

export const BUILD = BUILD_NAME;

let bootLogged = false;

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
  const loaded = loadSession(deviceAdapter(), data.clockEpoch, deviceNow());
  data.clockLive = { epoch: data.clockEpoch, session: loaded.session };
  console.log(trace("LOAD", data.clockLive.session.phase, loaded.session, deviceNow()));
  noteClockCommit(loaded.session, data.clockEpoch, { boot: true });
  armClockService(loaded.session);
  return data.clockLive.session;
}

function armClockService(session) {
  try {
    syncClockService(session);
  } catch (err) {
    console.log("FORREF_CLOCK_SLEEP service=unavailable");
  }
}

function observedBase(memory, utc) {
  if (utc == null) {
    return memory;
  }
  return preferObserved(memory, readStoredSession(deviceAdapter()), utc) || memory;
}

export function viewNow() {
  const session = currentSession();
  return present(session, session && session.lastUtc);
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
    commitSession(deviceAdapter(), failed.session);
    noteClockCommit(failed.session, epoch);
    console.log(trace("CLOCK_UNAVAILABLE", before.phase, failed.session, 0));
    return present(failed.session, failed.session.lastUtc);
  }
  const frame = liveFrame(observedBase(before, utc), utc, epoch);
  rememberSession(frame.session);
  if (!frame.admitted || frame.reason === "TICK") {
    const saved = commitForward(deviceAdapter(), frame.session);
    if (saved.reason === "KEPT_NEWER" && saved.session) {
      rememberSession(saved.session);
    } else if (!frame.admitted && saved.ok) {
      noteClockCommit(frame.session, epoch);
      console.log(trace("UNVERIFIED", before.phase, frame.session, utc));
    } else if (!saved.ok) {
      console.log("FORREF_CLOCK_SLEEP persist=fail");
      if (!frame.admitted) {
        noteClockCommit(frame.session, epoch);
        console.log(trace("UNVERIFIED", before.phase, frame.session, utc));
      }
    }
  }
  armClockService(frame.session);
  return frame.view;
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
      commitSession(deviceAdapter(), result.session);
      rememberSession(result.session);
      noteClockCommit(result.session, bag().clockEpoch);
    }
    return result;
  }
  const saved = commitSession(deviceAdapter(), result.session);
  if (!saved.ok) {
    console.log(trace("READBACK_FAIL", before.phase, before, utc));
    return { ok: false, reason: "READBACK_FAIL", session: before, before: before };
  }
  rememberSession(result.session);
  noteClockCommit(result.session, bag().clockEpoch);
  armClockService(result.session);
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
  const saved = commitForward(deviceAdapter(), chosen);
  rememberSession(saved.reason === "KEPT_NEWER" && saved.session ? saved.session : chosen);
  console.log("FORREF_CLOCK001 PERSIST|" + saved.reason + "!");
  return saved;
}
