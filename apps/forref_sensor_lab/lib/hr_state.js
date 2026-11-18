// Heart-rate display state. getLast() is last-known, never live.

export const HR_STALE_MS = 15000;

export function initialHr() {
  return {
    state: "STOPPED",
    live: false,
    lastKnown: false,
    sampleAgeMs: null,
    bpm: null,
  };
}

function usable(bpm) {
  return typeof bpm === "number" && isFinite(bpm) && bpm >= 30 && bpm <= 230;
}

export function reduceHr(state, event) {
  const current = state || initialHr();
  if (!event) {
    return current;
  }
  if (event.type === "init") {
    return { state: "INITIALIZING", live: false, lastKnown: false, sampleAgeMs: null, bpm: null };
  }
  if (event.type === "measuring") {
    return Object.assign({}, current, { state: "MEASURING", live: false, lastKnown: false });
  }
  if (event.type === "permission") {
    return { state: "PERMISSION_REQUIRED", live: false, lastKnown: false, sampleAgeMs: null, bpm: null };
  }
  if (event.type === "stop") {
    return { state: "STOPPED", live: false, lastKnown: false, sampleAgeMs: null, bpm: null };
  }
  if (event.type === "last") {
    if (current.live) {
      return current;
    }
    if (!usable(event.bpm)) {
      return { state: "UNAVAILABLE", live: false, lastKnown: false, sampleAgeMs: null, bpm: null };
    }
    return { state: "STALE", live: false, lastKnown: true, sampleAgeMs: null, bpm: event.bpm };
  }
  if (event.type === "sample") {
    if (!usable(event.bpm)) {
      return { state: "UNAVAILABLE", live: false, lastKnown: false, sampleAgeMs: null, bpm: null };
    }
    return { state: "LIVE", live: true, lastKnown: false, sampleAgeMs: 0, bpm: event.bpm };
  }
  if (event.type === "tick") {
    if (current.state !== "LIVE") {
      return current;
    }
    const age = event.sampleAgeMs;
    if (typeof age === "number" && age > HR_STALE_MS) {
      return Object.assign({}, current, { state: "STALE", live: false, lastKnown: true, sampleAgeMs: age });
    }
    return Object.assign({}, current, { sampleAgeMs: age });
  }
  return current;
}
