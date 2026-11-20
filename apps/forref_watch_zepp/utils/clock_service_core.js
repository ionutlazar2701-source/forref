// One background observation. The tick does not grant a second of match time.
// A denied permission, a gap wider than the continuity window, or a finished
// phase leaves the last good elapsed where it was.

import { liveFrame } from "./match_clock.js";
import { commitForward, preferObserved, readStoredSession, serviceShouldStop } from "./clock_continuity.js";

export function runServiceTick(adapter, utc, permission, memory) {
  if (permission !== "granted") {
    return { ok: false, reason: "PERMISSION_DENIED", session: memory || null, stop: false, wrote: false };
  }
  if (utc == null) {
    return { ok: false, reason: "CLOCK_UNAVAILABLE", session: memory || null, stop: false, wrote: false };
  }
  const stored = readStoredSession(adapter);
  const base = preferObserved(memory, stored, utc) || stored || memory;
  if (!base) {
    return { ok: false, reason: "NO_SESSION", session: null, stop: false, wrote: false };
  }
  if (serviceShouldStop(base)) {
    return { ok: true, reason: "STOP", session: base, stop: true, wrote: false };
  }
  const frame = liveFrame(base, utc, base.epoch);
  if (frame.reason !== "TICK" && frame.admitted !== false) {
    return {
      ok: frame.admitted === true,
      reason: frame.reason,
      session: frame.session,
      stop: serviceShouldStop(frame.session),
      wrote: false,
    };
  }
  const saved = commitForward(adapter, frame.session);
  if (saved.reason === "KEPT_NEWER" && saved.session) {
    return {
      ok: true,
      reason: "KEPT_NEWER",
      session: saved.session,
      stop: serviceShouldStop(saved.session),
      wrote: false,
    };
  }
  return {
    ok: frame.admitted === true,
    reason: frame.reason,
    session: frame.session,
    stop: serviceShouldStop(frame.session),
    wrote: saved.ok === true,
  };
}
