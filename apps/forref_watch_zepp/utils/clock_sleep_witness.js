// On-watch record of the screen-off chain. It is not match time.
// The Device App may write it while the screen is on.
// The App Service may write it only after noteServiceTick allows the write.

import { fnv32 } from "./match_clock.js";

export function emptyWitness() {
  return {
    startClass: "",
    running: false,
    offTicks: 0,
    maxDt: 0,
    lastCheckpointUtc: null,
    admit: "",
    recover: "",
    lastClass: "",
  };
}

function clone(witness) {
  const source = witness || emptyWitness();
  return {
    startClass: source.startClass || "",
    running: source.running === true,
    offTicks: source.offTicks || 0,
    maxDt: source.maxDt || 0,
    lastCheckpointUtc: source.lastCheckpointUtc == null ? null : source.lastCheckpointUtc,
    admit: source.admit || "",
    recover: source.recover || "",
    lastClass: source.lastClass || "",
  };
}

export function encodeWitness(witness) {
  const body = {
    v: 1,
    s: witness.startClass || "",
    run: witness.running ? 1 : 0,
    off: witness.offTicks || 0,
    max: witness.maxDt || 0,
    ck: witness.lastCheckpointUtc == null ? null : witness.lastCheckpointUtc,
    admit: witness.admit || "",
    rec: witness.recover || "",
    cls: witness.lastClass || "",
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
  if (!body || body.v !== 1) {
    return emptyWitness();
  }
  return {
    startClass: body.s || "",
    running: body.run === 1,
    offTicks: body.off || 0,
    maxDt: body.max || 0,
    lastCheckpointUtc: typeof body.ck === "number" ? body.ck : null,
    admit: body.admit || "",
    recover: body.rec || "",
    lastClass: body.cls || "",
  };
}

export function noteHost(witness, snap) {
  const next = clone(witness);
  if (snap && snap.startClass) {
    next.startClass = snap.startClass;
  }
  next.running = !!(snap && snap.running);
  return next;
}

export function noteRecover(witness, reason) {
  const next = clone(witness);
  next.recover = reason || "";
  return next;
}

export function noteAdmit(witness, reason) {
  const next = clone(witness);
  next.admit = reason || "";
  return next;
}

export function noteForegroundCheckpoint(witness, utc) {
  const next = clone(witness);
  if (utc != null) {
    next.lastCheckpointUtc = utc;
  }
  return next;
}

// Screen-on service ticks must not ask for a file write.
export function noteServiceTick(witness, event) {
  const next = clone(witness);
  const screen = event && event.screen;
  if (screen !== "off") {
    return { witness: next, write: false };
  }
  const dt = event.dt == null || event.dt === "" ? null : Number(event.dt);
  next.offTicks += 1;
  if (dt != null && isFinite(dt) && dt > next.maxDt) {
    next.maxDt = dt;
  }
  next.lastClass = event.class || "";
  if (event.class === "CHAIN" && event.committed === true && event.utc != null) {
    next.lastCheckpointUtc = event.utc;
  }
  return { witness: next, write: true };
}

export function recoverLabel(witness) {
  const admit = witness && witness.admit ? witness.admit : "";
  if (admit) {
    return admit;
  }
  return witness && witness.recover ? witness.recover : "-";
}

export function formatWitness(witness, now) {
  const current = clone(witness);
  let ck = "none";
  if (current.lastCheckpointUtc != null && now != null) {
    ck = String(now - current.lastCheckpointUtc);
  }
  return (
    "S=" +
    (current.startClass || "-") +
    " off=" +
    current.offTicks +
    " max=" +
    current.maxDt +
    " ck=" +
    ck +
    " r=" +
    recoverLabel(current)
  );
}
