// Display paints are not the match clock. Exact digits continue only while
// successive UTC observations stay inside DISPLAY_CONTINUITY_MS.
// Zepp Time.getTime() is UTC, not a sleep-inclusive monotonic clock.

import {
  DISPLAY_CONTINUITY_MS,
  Phase,
  Trust,
  commitSession,
  decodeSession,
  isRunning,
  liveFrame,
} from "./match_clock.js";

export function observationStep(session, utc) {
  if (!session || utc == null) {
    return null;
  }
  const anchor = session.lastUtc == null ? session.openStartUtc : session.lastUtc;
  if (anchor == null) {
    return null;
  }
  return utc - anchor;
}

export function chainFresh(session, utc) {
  if (!session || !isRunning(session.phase) || session.trust === Trust.UNVERIFIED) {
    return false;
  }
  const step = observationStep(session, utc);
  return step != null && step >= 0 && step <= DISPLAY_CONTINUITY_MS;
}

export function readStoredSession(adapter) {
  let fileRaw = "";
  let kvRaw = "";
  try {
    fileRaw = adapter.readFile();
  } catch (err) {
    return null;
  }
  try {
    kvRaw = adapter.readKv();
  } catch (err) {
    return null;
  }
  if (!fileRaw || !kvRaw || fileRaw !== kvRaw) {
    return null;
  }
  return decodeSession(String(fileRaw));
}

function isHold(session) {
  return !!(
    session &&
    !isRunning(session.phase) &&
    session.trust !== Trust.UNVERIFIED &&
    session.phase !== Phase.READY
  );
}

export function preferObserved(memory, stored, utc) {
  if (!stored) {
    return memory;
  }
  if (!memory) {
    return stored;
  }
  if (isHold(stored) && isRunning(memory.phase)) {
    return stored;
  }
  if (isHold(memory) && isRunning(stored.phase)) {
    return memory;
  }
  const storedFresh = chainFresh(stored, utc);
  const memoryFresh = chainFresh(memory, utc);
  if (storedFresh && (!memoryFresh || (stored.lastUtc || 0) >= (memory.lastUtc || 0))) {
    if (memoryFresh && memory.openStartUtc != null && stored.openStartUtc !== memory.openStartUtc) {
      return memory;
    }
    if (memoryFresh && isRunning(memory.phase) && memory.phase !== stored.phase) {
      return memory;
    }
    return stored;
  }
  if (memory.trust === Trust.UNVERIFIED && !storedFresh) {
    return memory;
  }
  if (!storedFresh && !memoryFresh && (stored.lastUtc || 0) > (memory.lastUtc || 0)) {
    if (memory.openStartUtc == null || stored.openStartUtc === memory.openStartUtc) {
      return stored;
    }
  }
  return memory;
}

export function projectFrame(memory, stored, utc, epoch) {
  const chosen = preferObserved(memory, stored, utc);
  if (!chosen) {
    return {
      admitted: false,
      reason: "NO_SESSION",
      session: null,
      view: { digits: null, unverified: true, lastKnown: null },
    };
  }
  return liveFrame(chosen, utc, epoch);
}

export function commitForward(adapter, session) {
  const stored = readStoredSession(adapter);
  if (stored && session && isHold(stored) && isRunning(session.phase)) {
    return { ok: true, reason: "KEPT_HOLD", session: stored };
  }
  if (stored && session && stored.trust !== Trust.UNVERIFIED && isRunning(stored.phase)) {
    const newer = (stored.lastUtc || 0) > (session.lastUtc || 0);
    const sameSegment = stored.openStartUtc === session.openStartUtc;
    if (newer && (sameSegment || session.trust === Trust.UNVERIFIED)) {
      return { ok: true, reason: "KEPT_NEWER", session: stored };
    }
  }
  return commitSession(adapter, session);
}

export function serviceShouldStop(session) {
  if (!session) {
    return false;
  }
  return !isRunning(session.phase) || session.trust === Trust.UNVERIFIED;
}

export function observeStored(adapter, utc) {
  const stored = readStoredSession(adapter);
  if (!stored) {
    return { frame: null, reason: "NO_SESSION" };
  }
  if (serviceShouldStop(stored)) {
    return { frame: liveFrame(stored, utc, stored.epoch), reason: "STOP" };
  }
  const frame = liveFrame(stored, utc, stored.epoch);
  return { frame: frame, reason: frame.reason };
}
