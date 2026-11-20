// On-watch record of service execution. It is not match time.
// The Device App may write it while the screen is on.
// A callback is counted before the screen is known.
// The first temporal invalidation stays. A later HELD sample does not replace it.

import { DISPLAY_CONTINUITY_MS, fnv32 } from "./match_clock.js";

const FAULTS = {
  UNSAMPLED_GAP: true,
  BACKWARD: true,
  EPOCH: true,
  CLOCK_UNAVAILABLE: true,
  RECOVERY_REQUIRED: true,
  STORE_UNAVAILABLE: true,
  CONFLICT: true,
  CORRUPT: true,
};

export function isTemporalFault(reason) {
  return !!FAULTS[reason];
}

export function emptyWitness() {
  return {
    startClass: "",
    running: false,
    callbacks: 0,
    offTicks: 0,
    maxDt: 0,
    lastScreen: "",
    writeAttempts: 0,
    writeOk: 0,
    readbackOk: 0,
    initSeen: false,
    destroyReason: "",
    fault: "",
    lastCheckpointUtc: null,
    admit: "",
    recover: "",
    lastClass: "",
    timerState: "",
    timerId: "",
    firstCallback: false,
    experimentState: "",
    experimentId: "",
    experimentTicks: 0,
    listed: "",
    diagReadback: false,
  };
}

function clone(witness) {
  const source = witness || emptyWitness();
  return {
    startClass: source.startClass || "",
    running: source.running === true,
    callbacks: source.callbacks || 0,
    offTicks: source.offTicks || 0,
    maxDt: source.maxDt || 0,
    lastScreen: source.lastScreen || "",
    writeAttempts: source.writeAttempts || 0,
    writeOk: source.writeOk || 0,
    readbackOk: source.readbackOk || 0,
    initSeen: source.initSeen === true,
    destroyReason: source.destroyReason || "",
    fault: source.fault || "",
    lastCheckpointUtc: source.lastCheckpointUtc == null ? null : source.lastCheckpointUtc,
    admit: source.admit || "",
    recover: source.recover || "",
    lastClass: source.lastClass || "",
    timerState: source.timerState || "",
    timerId: source.timerId || "",
    firstCallback: source.firstCallback === true,
    experimentState: source.experimentState || "",
    experimentId: source.experimentId || "",
    experimentTicks: source.experimentTicks || 0,
    listed: source.listed || "",
    diagReadback: source.diagReadback === true,
  };
}

export function encodeWitness(witness) {
  const body = {
    v: 3,
    s: witness.startClass || "",
    run: witness.running ? 1 : 0,
    n: witness.callbacks || 0,
    off: witness.offTicks || 0,
    max: witness.maxDt || 0,
    scr: witness.lastScreen || "",
    wa: witness.writeAttempts || 0,
    wk: witness.writeOk || 0,
    wb: witness.readbackOk || 0,
    ini: witness.initSeen ? 1 : 0,
    dead: witness.destroyReason || "",
    fault: witness.fault || "",
    ck: witness.lastCheckpointUtc == null ? null : witness.lastCheckpointUtc,
    admit: witness.admit || "",
    rec: witness.recover || "",
    cls: witness.lastClass || "",
    tm: witness.timerState || "",
    tid: witness.timerId || "",
    fc: witness.firstCallback ? 1 : 0,
    xs: witness.experimentState || "",
    xid: witness.experimentId || "",
    xn: witness.experimentTicks || 0,
    lst: witness.listed || "",
    drb: witness.diagReadback ? 1 : 0,
  };
  const json = JSON.stringify(body);
  return json + "#" + fnv32(json);
}

export function decodeWitness(raw) {
  if (typeof raw !== "string" || raw.indexOf("#") < 0) {
    return emptyWitness();
  }
  const cut = raw.lastIndexOf("#");
  const json = raw.slice(0, cut);
  const hash = raw.slice(cut + 1);
  if (fnv32(json) !== hash) {
    return emptyWitness();
  }
  let body;
  try {
    body = JSON.parse(json);
  } catch (err) {
    return emptyWitness();
  }
  if (!body || (body.v !== 1 && body.v !== 2 && body.v !== 3)) {
    return emptyWitness();
  }
  return {
    startClass: body.s || "",
    running: body.run === 1,
    callbacks: body.n || 0,
    offTicks: body.off || 0,
    maxDt: body.max || 0,
    lastScreen: body.scr || "",
    writeAttempts: body.wa || 0,
    writeOk: body.wk || 0,
    readbackOk: body.wb || 0,
    initSeen: body.ini === 1,
    destroyReason: body.dead || "",
    fault: body.fault || "",
    lastCheckpointUtc: typeof body.ck === "number" ? body.ck : null,
    admit: body.admit || "",
    recover: body.rec || "",
    lastClass: body.cls || "",
    timerState: body.tm || "",
    timerId: body.tid || "",
    firstCallback: body.fc === 1,
    experimentState: body.xs || "",
    experimentId: body.xid || "",
    experimentTicks: body.xn || 0,
    listed: body.lst || "",
    diagReadback: body.drb === 1,
  };
}

export function noteHost(witness, snap) {
  const next = clone(witness);
  if (snap && snap.startClass) {
    next.startClass = snap.startClass;
  }
  if (snap && snap.listed) {
    next.listed = snap.listed;
  }
  next.running = !!(snap && snap.running);
  return next;
}

export function noteRecover(witness, reason) {
  const next = clone(witness);
  const incoming = reason || "";
  if (!next.recover || !isTemporalFault(next.recover)) {
    next.recover = incoming;
  }
  if (isTemporalFault(incoming) && !next.fault) {
    next.fault = incoming;
  }
  return next;
}

export function noteAdmit(witness, reason) {
  const next = clone(witness);
  const incoming = reason || "";
  if (isTemporalFault(incoming) && !next.fault) {
    next.fault = incoming;
  }
  if (incoming === "HELD" && (next.fault || isTemporalFault(next.admit))) {
    if (!next.fault && isTemporalFault(next.admit)) {
      next.fault = next.admit;
    }
    return next;
  }
  next.admit = incoming;
  return next;
}

export function noteForegroundCheckpoint(witness, utc) {
  const next = clone(witness);
  if (utc != null) {
    next.lastCheckpointUtc = utc;
  }
  return next;
}

// Count the callback before any screen value is applied.
export function noteCallback(witness, dt) {
  const next = clone(witness);
  next.callbacks += 1;
  next.firstCallback = true;
  const value = dt == null || dt === "" ? null : Number(dt);
  if (value != null && isFinite(value) && value > next.maxDt) {
    next.maxDt = value;
  }
  return next;
}

export function noteScreen(witness, screen) {
  const next = clone(witness);
  next.lastScreen = screen || "unk";
  if (next.lastScreen === "off") {
    next.offTicks += 1;
  }
  return next;
}

export function noteLife(witness, life) {
  const next = clone(witness);
  if (life && life.init) {
    next.initSeen = true;
  }
  if (life && life.destroy && !next.destroyReason) {
    next.destroyReason = life.destroy;
  }
  return next;
}

export function noteClass(witness, label) {
  const next = clone(witness);
  if (label) {
    next.lastClass = label;
  }
  return next;
}

export function noteCheckpoint(witness, utc) {
  const next = clone(witness);
  if (typeof utc === "number" && (next.lastCheckpointUtc == null || utc > next.lastCheckpointUtc)) {
    next.lastCheckpointUtc = utc;
  }
  return next;
}

export function noteFault(witness, reason) {
  const next = clone(witness);
  if (isTemporalFault(reason) && !next.fault) {
    next.fault = reason;
  }
  return next;
}

export function noteTimer(witness, result) {
  const next = clone(witness);
  const state = result && result.state ? result.state : "";
  const id = result && result.id != null && result.id !== false && result.id !== "" ? String(result.id) : "";
  if (state && !next.timerState) {
    next.timerState = state;
  }
  if (id && !next.timerId) {
    next.timerId = id;
  }
  return next;
}

export function noteExperiment(witness, result) {
  const next = clone(witness);
  const state = result && result.state ? result.state : "";
  const id = result && result.id != null && result.id !== false && result.id !== "" ? String(result.id) : "";
  if (state && !next.experimentState) {
    next.experimentState = state;
  }
  if (id && !next.experimentId) {
    next.experimentId = id;
  }
  return next;
}

export function noteExperimentTick(witness) {
  const next = clone(witness);
  next.experimentTicks += 1;
  return next;
}

export function noteDiagReadback(witness) {
  const next = clone(witness);
  next.diagReadback = true;
  return next;
}

export function noteWrite(witness, outcome) {
  const next = clone(witness);
  next.writeAttempts += 1;
  if (outcome && outcome.ok) {
    next.writeOk += 1;
  }
  if (outcome && outcome.readback) {
    next.readbackOk += 1;
  }
  return next;
}

export function noteServiceTick(witness, event) {
  const source = event || {};
  let next = noteCallback(witness, source.dt);
  if (source.screen) {
    next = noteScreen(next, source.screen);
  }
  next = noteClass(next, source.class || "");
  if (source.class === "CHAIN" && source.committed === true && source.utc != null) {
    next = noteCheckpoint(next, source.utc);
  }
  const fault = isTemporalFault(source.reason) ? source.reason : source.class;
  next = noteFault(next, fault);
  return { witness: next, write: true };
}

export function mergeServiceLedger(fileWitness, local) {
  const next = clone(fileWitness);
  const side = clone(local);
  next.callbacks = Math.max(next.callbacks, side.callbacks);
  next.offTicks = Math.max(next.offTicks, side.offTicks);
  next.maxDt = Math.max(next.maxDt, side.maxDt);
  next.writeAttempts = Math.max(next.writeAttempts, side.writeAttempts);
  next.writeOk = Math.max(next.writeOk, side.writeOk);
  next.readbackOk = Math.max(next.readbackOk, side.readbackOk);
  if (side.initSeen) {
    next.initSeen = true;
  }
  if (side.destroyReason) {
    next.destroyReason = side.destroyReason;
  }
  if (side.lastScreen) {
    next.lastScreen = side.lastScreen;
  }
  if (side.lastClass) {
    next.lastClass = side.lastClass;
  }
  if (!next.fault && side.fault) {
    next.fault = side.fault;
  }
  if (typeof side.lastCheckpointUtc === "number" && (next.lastCheckpointUtc == null || side.lastCheckpointUtc > next.lastCheckpointUtc)) {
    next.lastCheckpointUtc = side.lastCheckpointUtc;
  }
  if (side.timerState) {
    next.timerState = side.timerState;
  }
  if (side.timerId) {
    next.timerId = side.timerId;
  }
  if (side.firstCallback) {
    next.firstCallback = true;
  }
  if (side.experimentState) {
    next.experimentState = side.experimentState;
  }
  if (side.experimentId) {
    next.experimentId = side.experimentId;
  }
  next.experimentTicks = Math.max(next.experimentTicks, side.experimentTicks);
  if (side.diagReadback) {
    next.diagReadback = true;
  }
  return next;
}

export function sameEvidence(left, right) {
  const a = clone(left);
  const b = clone(right);
  return a.callbacks === b.callbacks
    && a.maxDt === b.maxDt
    && a.initSeen === b.initSeen
    && a.fault === b.fault
    && a.lastScreen === b.lastScreen
    && a.destroyReason === b.destroyReason
    && a.timerState === b.timerState
    && a.timerId === b.timerId
    && a.firstCallback === b.firstCallback
    && a.experimentState === b.experimentState
    && a.experimentTicks === b.experimentTicks;
}

// First missing durable link. A start code is not one of these.
export function executionLink(witness) {
  const current = clone(witness);
  if (!current.initSeen && current.callbacks === 0) {
    return "SERVICE";
  }
  if (current.callbacks === 0) {
    return "TIMER";
  }
  if (current.writeOk === 0) {
    return "WRITE";
  }
  if (current.readbackOk === 0) {
    return "READ";
  }
  if (current.maxDt > DISPLAY_CONTINUITY_MS || isTemporalFault(current.fault)) {
    return "GAP";
  }
  return "CHAIN";
}

export function recoverLabel(witness) {
  if (witness && witness.fault) {
    return witness.fault;
  }
  const admit = witness && witness.admit ? witness.admit : "";
  if (admit) {
    return admit;
  }
  return witness && witness.recover ? witness.recover : "-";
}

function shownId(value) {
  const text = value || "-";
  if (text.length <= 8) {
    return text;
  }
  return text.slice(text.length - 8);
}

function shownExperiment(witness) {
  if (witness.experimentState === "failed") {
    return "fail";
  }
  if (!witness.experimentState) {
    return "-";
  }
  return String(witness.experimentTicks || 0);
}

function shownListed(value) {
  if (value === "yes") {
    return "1";
  }
  if (value === "no") {
    return "0";
  }
  if (value === "fail") {
    return "x";
  }
  return "-";
}

// One short line. The round face clipped the longer 1.0.9 line before destroy.
export function formatWitness(witness) {
  const current = clone(witness);
  const timer = current.timerState === "created" ? "ok" : current.timerState === "failed" ? "fail" : "-";
  return "T=" + timer
    + " id=" + shownId(current.timerId)
    + " D=" + (current.destroyReason || "-")
    + " F=" + (current.firstCallback ? "1" : "0")
    + " X=" + shownExperiment(current)
    + " A=" + shownListed(current.listed)
    + " b=" + (current.diagReadback ? "1" : "0");
}

// What the durable timer fields can already prove. Match time stays elsewhere.
export function timerDiagnosis(witness) {
  const current = clone(witness);
  if (!current.timerState) {
    return "UNRECORDED";
  }
  if (current.timerState === "failed") {
    return "NOT_CREATED";
  }
  if (current.destroyReason && !current.firstCallback) {
    return "DESTROYED_BEFORE_CALLBACK";
  }
  if (current.firstCallback) {
    return "CALLBACK_RECORDED";
  }
  if (current.experimentTicks > 0) {
    return "LONG_PERIOD_ONLY";
  }
  if (current.listed === "yes") {
    return "NOT_DELIVERED";
  }
  if (current.listed === "no") {
    return "SERVICE_ABSENT";
  }
  return "NO_CALLBACK";
}
