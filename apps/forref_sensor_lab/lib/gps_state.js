// GPS acquisition state. Weak or invalid samples do not stop the receiver.

export const FRESH_MS = 5000;
export const LOST_MS = 15000;

export function emptyGpsMeta() {
  return {
    satellitesUsed: null,
    satellitesValid: null,
    signal: null,
    agpsTimestamp: null,
    quality: "UNAVAILABLE",
  };
}

function finiteCoord(event) {
  return typeof event.lat === "number" && typeof event.lon === "number" && event.lat >= -90 && event.lat <= 90 && event.lon >= -180 && event.lon <= 180;
}

function readMeta(event) {
  const meta = emptyGpsMeta();
  if (!event || event.metaPresent !== true) {
    return meta;
  }
  meta.quality = "PRESENT";
  meta.satellitesUsed = typeof event.satellitesUsed === "number" ? event.satellitesUsed : null;
  meta.satellitesValid = typeof event.satellitesValid === "number" ? event.satellitesValid : null;
  meta.signal = typeof event.signal === "number" ? event.signal : null;
  meta.agpsTimestamp = typeof event.agpsTimestamp === "number" ? event.agpsTimestamp : null;
  return meta;
}

export function initialGps() {
  return {
    state: "STOPPED",
    acquiring: false,
    hadFix: false,
    gapOpen: false,
    lastGoodElapsed: null,
    meta: emptyGpsMeta(),
    transition: "",
    accept: false,
    bridge: false,
  };
}

export function attachGpsMeta(state, event) {
  const current = state || initialGps();
  const meta = readMeta(Object.assign({ metaPresent: true }, event || {}));
  if (meta.satellitesUsed !== 0) {
    return Object.assign({}, current, { meta: meta, transition: "", accept: false, bridge: false });
  }
  if (!current.hadFix) {
    return Object.assign({}, current, { meta: meta, state: current.acquiring ? "SEARCHING" : current.state, transition: "", accept: false, bridge: false });
  }
  return Object.assign({}, current, {
    meta: meta,
    state: "WEAK_OR_STALE",
    gapOpen: true,
    transition: "WEAK_OR_STALE",
    accept: false,
    bridge: false,
    acquiring: current.acquiring,
  });
}

export function reduceGps(state, event) {
  const current = state || initialGps();
  if (!event) {
    return current;
  }
  if (event.type === "unsupported") {
    return Object.assign({}, current, { state: "UNSUPPORTED", acquiring: false, transition: "UNSUPPORTED", accept: false, bridge: false });
  }
  if (event.type === "permission") {
    return Object.assign({}, current, { state: "PERMISSION_REQUIRED", acquiring: false, transition: "PERMISSION_REQUIRED", accept: false, bridge: false });
  }
  if (event.type === "error") {
    return Object.assign({}, current, { state: "ERROR", transition: "ERROR", accept: false, bridge: false });
  }
  if (event.type === "stop") {
    return Object.assign({}, current, { state: "STOPPED", acquiring: false, transition: "STOPPED", accept: false, bridge: false });
  }
  if (event.type === "start") {
    return Object.assign({}, current, { state: "SEARCHING", acquiring: true, transition: "SEARCHING", accept: false, bridge: false });
  }
  if (event.type === "tick") {
    if (!current.acquiring || current.lastGoodElapsed == null || typeof event.elapsedMs !== "number") {
      return Object.assign({}, current, { transition: "", accept: false, bridge: false });
    }
    const age = event.elapsedMs - current.lastGoodElapsed;
    if (age > LOST_MS && current.state !== "LOST" && current.state !== "STOPPED") {
      return Object.assign({}, current, { state: "LOST", gapOpen: true, transition: "LOST", accept: false, bridge: false });
    }
    if (age > FRESH_MS && (current.state === "READY" || current.state === "RECOVERED")) {
      return Object.assign({}, current, { state: "WEAK_OR_STALE", gapOpen: true, transition: "WEAK_OR_STALE", accept: false, bridge: false });
    }
    return Object.assign({}, current, { transition: "", accept: false, bridge: false });
  }
  if (event.type !== "sample") {
    return current;
  }
  const meta = readMeta(event);
  const valid = event.status === "A" && finiteCoord(event);
  const weak = meta.satellitesUsed === 0;
  if (!valid || weak) {
    const next = current.hadFix ? "WEAK_OR_STALE" : "SEARCHING";
    return Object.assign({}, current, {
      state: next,
      acquiring: true,
      gapOpen: current.hadFix ? true : current.gapOpen,
      transition: next,
      accept: false,
      bridge: false,
      meta: meta,
    });
  }
  const recover = current.gapOpen || current.state === "LOST" || current.state === "WEAK_OR_STALE";
  return Object.assign({}, current, {
    state: recover ? "RECOVERED" : "READY",
    acquiring: true,
    hadFix: true,
    gapOpen: false,
    lastGoodElapsed: event.elapsedMs,
    transition: recover ? "RECOVERED" : "READY",
    accept: true,
    bridge: recover ? false : current.hadFix,
    meta: meta,
  });
}
