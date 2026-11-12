// One prototype session for Live A and Live C. Not a second clock and not Match Memory.
import { state } from "./state";
import {
  applyIntent,
  sample,
  present,
  trace,
  loadSession,
  commitSession,
  Trust,
} from "./match_clock";
import { deviceNow, deviceAdapter } from "./clock_device";

export const BUILD = "live-match-flow-002";

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
    console.log("FORREF_LIVE002_BOOT build=" + BUILD + "!");
  }
  if (data.clockLive && data.clockLive.epoch === data.clockEpoch && data.clockLive.session) {
    return data.clockLive.session;
  }
  const loaded = loadSession(deviceAdapter(), data.clockEpoch);
  data.clockLive = { epoch: data.clockEpoch, session: loaded.session };
  console.log(trace("LOAD", data.clockLive.session.phase, loaded.session, deviceNow()));
  return data.clockLive.session;
}

export function viewNow() {
  return present(currentSession(), deviceNow());
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
  const result = applyIntent(before, intent, observation(intent, before, extra));
  console.log(trace(result.ok ? result.reason : "REJECT", before.phase, result.session, utc));
  if (!result.ok) {
    if (result.session !== before && result.session.trust === Trust.UNVERIFIED) {
      commitSession(deviceAdapter(), result.session);
      rememberSession(result.session);
    }
    return result;
  }
  const saved = commitSession(deviceAdapter(), result.session);
  if (!saved.ok) {
    console.log(trace("READBACK_FAIL", before.phase, before, utc));
    return { ok: false, reason: "READBACK_FAIL", session: before, before: before };
  }
  rememberSession(result.session);
  return result;
}

export function sampleTick() {
  const before = currentSession();
  const utc = deviceNow();
  if (!before) {
    return null;
  }
  if (utc == null) {
    const failed = sample(before, { utcMillis: null, epoch: bag().clockEpoch });
    rememberSession(failed.session);
    console.log(trace("CLOCK_UNAVAILABLE", before.phase, failed.session, 0));
    return failed;
  }
  const sampled = sample(before, { utcMillis: utc, epoch: bag().clockEpoch });
  rememberSession(sampled.session);
  if (sampled.event === "UNVERIFIED") {
    commitSession(deviceAdapter(), sampled.session);
    console.log(trace("UNVERIFIED", before.phase, sampled.session, utc));
    return sampled;
  }
  if (sampled.event === "TICK") {
    console.log(trace("TICK", before.phase, sampled.session, utc));
  }
  return sampled;
}
