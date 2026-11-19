// Experimental match telemetry. Not Match Memory, not D1, and not a saved distance.
// The match clock decides the phase. Meter admission closes in memory before any sensor or storage work.

import { advanceDistance } from "../../forref_sensor_lab/lib/analytics.js";
import { initialGps, reduceGps } from "../../forref_sensor_lab/lib/gps_state.js";
import { initialHr, reduceHr } from "../../forref_sensor_lab/lib/hr_state.js";

const KEY = "__FORREF_MATCH_TELEMETRY__";
const ACTIVE = {
  FIRST_HALF_RUNNING: "first",
  SECOND_HALF_RUNNING: "second",
};

export function formatTelemetryLine(reading, labels) {
  const body = reading || {};
  const text = labels || {};
  const distance = body.distanceKnown
    ? String(text.prefix || "") + formatDistanceKm(body.distanceMeters, text.lang)
    : String(text.none || "");
  const hr = body.hrFresh && typeof body.hrBpm === "number"
    ? String(text.hrValue || "").replace("{n}", String(Math.round(body.hrBpm)))
    : String(text.hr || "");
  return distance + "  " + hr + "  " + String(text.gps || "");
}

export function formatDistanceKm(meters, lang) {
  const safe = typeof meters === "number" && isFinite(meters) && meters > 0 ? meters : 0;
  const hundredths = Math.round(safe / 10);
  const whole = Math.floor(hundredths / 100);
  const frac = String(hundredths % 100).padStart(2, "0");
  const sep = lang === "ro-RO" ? "," : ".";
  return whole + sep + frac + " km";
}

export function hrStatusKey(state) {
  if (state === "LIVE") return "hrLive";
  if (state === "STALE") return "hrLast";
  if (state === "MEASURING" || state === "INITIALIZING") return "hrSearch";
  if (state === "STOPPED") return "hrOff";
  if (state === "PERMISSION_REQUIRED") return "hrPermission";
  if (state === "UNAVAILABLE") return "hrUnavailable";
  if (state === "ERROR") return "hrError";
  return "hrNone";
}

export function gpsStatusKey(state) {
  if (state === "READY") return "gpsReady";
  if (state === "RECOVERED") return "gpsBack";
  if (state === "SEARCHING") return "gpsSearch";
  if (state === "WEAK_OR_STALE") return "gpsWeak";
  if (state === "LOST") return "gpsLost";
  if (state === "PERMISSION_REQUIRED") return "gpsPermission";
  if (state === "UNSUPPORTED" || state === "ERROR") return "gpsNone";
  if (state === "STOPPED") return "gpsOff";
  return "gpsNone";
}

export function matchKeyFromSession(session) {
  const ids = session && Array.isArray(session.appliedIntentIds) ? session.appliedIntentIds : [];
  for (let i = 0; i < ids.length; i++) {
    const id = ids[i];
    if (typeof id === "string" && id.indexOf("KICK_OFF-") === 0) {
      return id;
    }
  }
  return "";
}

function idleView() {
  return {
    distanceMeters: 0,
    firstMeters: 0,
    secondMeters: 0,
    hrState: "STOPPED",
    hrBpm: null,
    hrFresh: false,
    gpsState: "STOPPED",
    experimental: true,
    distanceSaved: false,
    official: false,
    distanceKnown: false,
    uncertified: 0,
    released: false,
    openHalf: null,
    dirty: false,
    storageStatus: "ABSENT",
    association: "UNRESOLVED",
  };
}

function activeHalf(phase, trust) {
  if (trust === "TIME_UNVERIFIED") {
    return null;
  }
  return ACTIVE[phase] || null;
}

function checksum(text) {
  let hash = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  return (hash >>> 0).toString(16).padStart(8, "0");
}

function parseStore(text) {
  if (!text) {
    return null;
  }
  const parts = String(text).split("|");
  if (parts.length !== 6 || parts[0] !== "T2") {
    return { corrupt: true };
  }
  const body = parts.slice(0, 5).join("|");
  if (checksum(body) !== parts[5]) {
    return { corrupt: true };
  }
  let matchKey = "";
  try {
    matchKey = decodeURIComponent(parts[1]);
  } catch (err) {
    return { corrupt: true };
  }
  const first = Number(parts[2]);
  const second = Number(parts[3]);
  const flag = Number(parts[4]);
  if (!isFinite(first) || !isFinite(second) || first < 0 || second < 0 || !isFinite(flag) || flag < 0) {
    return { corrupt: true };
  }
  return {
    corrupt: false,
    matchKey: matchKey,
    first: first / 1000,
    second: second / 1000,
    uncertified: flag,
  };
}

function readOutcome(store) {
  let result;
  try {
    result = store.read();
  } catch (err) {
    return { status: "READ_FAILED", pending: null };
  }
  if (typeof result === "string") {
    result = result ? { status: "OK", text: result } : { status: "NOT_FOUND", text: "" };
  }
  if (!result || result.status === "NOT_FOUND") {
    return { status: "ABSENT", pending: null };
  }
  if (result.status !== "OK") {
    return { status: result.status || "READ_FAILED", pending: null };
  }
  const parsed = parseStore(result.text);
  if (!parsed || parsed.corrupt) {
    return { status: "CORRUPT", pending: null };
  }
  if (!parsed.matchKey) {
    return { status: "UNRESOLVED", pending: null };
  }
  return { status: "PENDING", pending: parsed };
}

export function createMatchTelemetry(options) {
  const store = options && options.store ? options.store : null;
  let epoch = options && options.epoch ? options.epoch : "";
  let matchKey = "";
  let phase = "READY";
  let trust = "FROZEN_OBSERVED";
  let firstMeters = 0;
  let secondMeters = 0;
  let anchor = null;
  let recentSpeeds = [];
  let needAnchor = true;
  let openHalf = null;
  let eligibleSince = null;
  let generation = 1;
  let gps = initialGps();
  let hr = initialHr();
  let uncertified = 0;
  let released = false;
  let dirty = false;
  let pending = null;
  let sawStoreFault = false;
  let hrMark = null;
  let distanceKnown = false;
  let storageStatus = "ABSENT";
  let association = "UNRESOLVED";

  if (store) {
    const loaded = readOutcome(store);
    storageStatus = loaded.status;
    pending = loaded.pending;
    if (loaded.status === "READ_FAILED" || loaded.status === "CORRUPT") {
      uncertified += 1;
    }
  }

  function liveBpm() {
    if (hr.state === "LIVE" && hr.live === true && typeof hr.bpm === "number") {
      return hr.bpm;
    }
    return null;
  }

  function view() {
    const bpm = liveBpm();
    return {
      distanceMeters: firstMeters + secondMeters,
      firstMeters: firstMeters,
      secondMeters: secondMeters,
      hrState: hr.state,
      hrBpm: bpm,
      hrFresh: bpm != null,
      gpsState: gps.state,
      experimental: true,
      distanceSaved: false,
      official: false,
      distanceKnown: distanceKnown,
      uncertified: uncertified,
      released: released,
      openHalf: openHalf,
      dirty: dirty,
      epoch: epoch,
      matchKey: matchKey,
      storageStatus: storageStatus,
      association: association,
    };
  }

  function payload() {
    const key = encodeURIComponent(matchKey || "");
    const body = "T2|" + key + "|" + Math.round(firstMeters * 1000) + "|" + Math.round(secondMeters * 1000) + "|" + uncertified;
    return body + "|" + checksum(body);
  }

  function noteStoreFault(reason) {
    storageStatus = reason || "WRITE_FAILED";
    if (!sawStoreFault) {
      uncertified += 1;
      sawStoreFault = true;
    }
  }

  function persist() {
    if (!dirty) {
      return { ok: true, skipped: true };
    }
    if (!store) {
      dirty = false;
      return { ok: true, skipped: true };
    }
    if (!matchKey) {
      association = "UNRESOLVED";
    }
    const line = payload();
    try {
      const result = store.write(line);
      if (!result || result.ok === false) {
        noteStoreFault(result && result.reason ? result.reason : "UNVERIFIED");
        return { ok: false, reason: storageStatus };
      }
      dirty = false;
      sawStoreFault = false;
      storageStatus = "CHECKPOINT";
      association = "MATCHED";
      return { ok: true, reason: result.reason || "READBACK" };
    } catch (err) {
      noteStoreFault("WRITE_FAILED");
      return { ok: false, reason: "WRITE_FAILED" };
    }
  }

  function closeInterval() {
    generation += 1;
    anchor = null;
    recentSpeeds = [];
    needAnchor = true;
    openHalf = null;
    eligibleSince = null;
  }

  function openInterval(half, openedAtMs) {
    generation += 1;
    anchor = null;
    recentSpeeds = [];
    needAnchor = true;
    openHalf = half;
    eligibleSince = typeof openedAtMs === "number" && isFinite(openedAtMs) ? openedAtMs : null;
  }

  function resetMatch() {
    firstMeters = 0;
    secondMeters = 0;
    uncertified = 0;
    pending = null;
    sawStoreFault = false;
    distanceKnown = false;
    hrMark = null;
    dirty = true;
    storageStatus = "ABSENT";
    association = "UNRESOLVED";
    closeInterval();
    gps = initialGps();
    hr = initialHr();
    released = false;
  }

  function applyAdmission(nextOpen, openedAtMs) {
    if (nextOpen && openHalf !== nextOpen) {
      if (openHalf) {
        closeInterval();
      }
      openInterval(nextOpen, openedAtMs);
      return;
    }
    if (!nextOpen && openHalf) {
      closeInterval();
    }
  }

  function bootFrom(next, nextEpoch, nextKey) {
    epoch = nextEpoch || epoch;
    matchKey = nextKey || "";
    phase = next.phase || phase;
    trust = next.trust || trust;
    const sameMatch = !!(pending && pending.matchKey && matchKey && pending.matchKey === matchKey);
    if (phase !== "READY" && sameMatch) {
      firstMeters = pending.first;
      secondMeters = pending.second;
      uncertified = pending.uncertified;
      distanceKnown = firstMeters + secondMeters > 0;
      storageStatus = "RESTORED";
      association = "MATCHED";
    } else if (pending && pending.matchKey && matchKey && pending.matchKey !== matchKey) {
      storageStatus = "CONFLICT";
      association = "CONFLICT";
      uncertified += 1;
      distanceKnown = false;
    } else if (pending && pending.matchKey && !matchKey) {
      storageStatus = "UNRESOLVED";
      association = "UNRESOLVED";
      uncertified += 1;
    } else if (!matchKey) {
      association = "UNRESOLVED";
    }
    pending = null;
    closeInterval();
    released = phase === "FULL_TIME" || phase === "ABANDONED";
    const nextOpen = activeHalf(phase, trust);
    if (nextOpen && !released) {
      openInterval(nextOpen, next.openedAtMs);
    }
    return view();
  }

  function afterClock(info) {
    const next = info || {};
    const boot = next.boot === true;
    const nextEpoch = next.epoch || epoch;
    const nextKey = typeof next.matchKey === "string" ? next.matchKey : matchKey;
    if (boot) {
      return bootFrom(next, nextEpoch, nextKey);
    }
    const epochChanged = !!(epoch && nextEpoch && nextEpoch !== epoch);
    const keyChanged = !!(matchKey && nextKey && nextKey !== matchKey);
    if (epochChanged || keyChanged) {
      resetMatch();
    }
    if (next.phase === phase && next.trust === trust && (nextEpoch || "") === (epoch || "") && (nextKey || "") === (matchKey || "")) {
      epoch = nextEpoch || epoch;
      matchKey = nextKey || "";
      return view();
    }
    epoch = nextEpoch || epoch;
    matchKey = nextKey || "";
    const previous = phase;
    if (previous === "READY" && next.phase === "FIRST_HALF_RUNNING") {
      resetMatch();
      epoch = nextEpoch || epoch;
      matchKey = nextKey || "";
    }
    phase = next.phase || phase;
    trust = next.trust || trust;
    released = phase === "FULL_TIME" || phase === "ABANDONED";
    applyAdmission(released ? null : activeHalf(phase, trust), next.openedAtMs);
    if (matchKey) {
      association = association === "CONFLICT" ? association : "MATCHED";
    } else {
      association = "UNRESOLVED";
    }
    dirty = true;
    return view();
  }

  function sampleTime(sample) {
    if (sample && typeof sample.observedAtMs === "number" && isFinite(sample.observedAtMs)) {
      return sample.observedAtMs;
    }
    if (sample && typeof sample.elapsedMs === "number" && isFinite(sample.elapsedMs)) {
      return sample.elapsedMs;
    }
    return null;
  }

  function admitSample(sample) {
    const body = sample || {};
    if (body.generation != null && body.generation !== generation) {
      return false;
    }
    if (body.provenance === "UNCERTAIN") {
      return false;
    }
    const time = sampleTime(body);
    if (time == null) {
      return false;
    }
    if (eligibleSince != null && time < eligibleSince) {
      return false;
    }
    return true;
  }

  function onGnss(sample) {
    if (released) {
      return view();
    }
    const body = sample || {};
    if (!admitSample(body)) {
      return view();
    }
    const elapsed = sampleTime(body);
    const beforeGap = gps.gapOpen;
    const beforeState = gps.state;
    gps = reduceGps(gps, {
      type: "sample",
      status: body.status,
      lat: body.lat,
      lon: body.lon,
      elapsedMs: elapsed,
      metaPresent: body.metaPresent === true,
      satellitesUsed: body.satellitesUsed,
      satellitesValid: body.satellitesValid,
      signal: body.signal,
      agpsTimestamp: body.agpsTimestamp,
    });
    if ((gps.gapOpen && !beforeGap) || gps.state === "LOST" || (gps.state === "RECOVERED" && beforeState !== "RECOVERED")) {
      anchor = null;
      needAnchor = true;
    }
    if (!openHalf || !gps.accept) {
      return view();
    }
    const point = { lat: body.lat, lon: body.lon, elapsedMs: elapsed };
    if (needAnchor || !anchor || gps.bridge !== true) {
      anchor = point;
      needAnchor = false;
      recentSpeeds = [];
      distanceKnown = true;
      return view();
    }
    const step = advanceDistance(anchor, recentSpeeds, point);
    anchor = step.anchor;
    recentSpeeds = step.recentSpeeds;
    if (step.added > 0 && openHalf === "first") {
      firstMeters += step.added;
      distanceKnown = true;
      dirty = true;
    } else if (step.added > 0 && openHalf === "second") {
      secondMeters += step.added;
      distanceKnown = true;
      dirty = true;
    }
    return view();
  }

  function onHr(event) {
    if (released) {
      return view();
    }
    const body = event || {};
    if (body.type === "sample" && typeof body.elapsedMs === "number" && isFinite(body.elapsedMs)) {
      hrMark = body.elapsedMs;
    }
    hr = reduceHr(hr, body);
    return view();
  }

  function pulse(elapsedMs) {
    if (released) {
      return view();
    }
    const beforeGap = gps.gapOpen;
    gps = reduceGps(gps, { type: "tick", elapsedMs: elapsedMs });
    if (gps.gapOpen && !beforeGap) {
      anchor = null;
      needAnchor = true;
    }
    if (hr.state === "LIVE" && hrMark != null && typeof elapsedMs === "number") {
      hr = reduceHr(hr, { type: "tick", sampleAgeMs: elapsedMs - hrMark });
    }
    return view();
  }

  function noteGps(kind) {
    if (kind === "start") {
      gps = reduceGps(gps, { type: "start" });
      anchor = null;
      needAnchor = true;
      return;
    }
    if (kind === "stop") {
      gps = reduceGps(gps, { type: "stop" });
      anchor = null;
      needAnchor = true;
      return;
    }
    if (kind === "unsupported") {
      gps = reduceGps(gps, { type: "unsupported" });
      return;
    }
    if (kind === "permission") {
      gps = reduceGps(gps, { type: "permission" });
      return;
    }
    gps = reduceGps(gps, { type: "error" });
  }

  function noteHr(kind) {
    if (kind === "measuring") {
      hr = reduceHr(hr, { type: "measuring" });
      return;
    }
    if (kind === "permission") {
      hr = reduceHr(hr, { type: "permission" });
      return;
    }
    if (kind === "stop") {
      hr = reduceHr(hr, { type: "stop" });
      hrMark = null;
      return;
    }
    if (kind === "error") {
      hr = reduceHr(hr, { type: "error" });
      return;
    }
    hr = reduceHr(hr, { type: "init" });
  }

  function demand() {
    return {
      gps: openHalf != null && !released,
      hr: !released && phase !== "READY" && phase !== "FULL_TIME" && phase !== "ABANDONED",
      release: released,
    };
  }

  function release() {
    closeInterval();
    released = true;
    gps = reduceGps(gps, { type: "stop" });
    hr = reduceHr(hr, { type: "stop" });
    hrMark = null;
    dirty = true;
    persist();
    return view();
  }

  return {
    afterClock: afterClock,
    onGnss: onGnss,
    onHr: onHr,
    pulse: pulse,
    noteGps: noteGps,
    noteHr: noteHr,
    demand: demand,
    flush: persist,
    release: release,
    view: view,
    captureToken: function () {
      return generation;
    },
  };
}

export function installMatchTelemetry(host) {
  globalThis[KEY] = host;
}

export function matchTelemetry() {
  return globalThis[KEY] || null;
}

export function noteClockCommit(session, epoch, options) {
  const host = matchTelemetry();
  if (!host || !session) {
    return;
  }
  try {
    host.followClock({
      epoch: epoch || "",
      phase: session.phase,
      trust: session.trust,
      boot: !!(options && options.boot),
      matchKey: matchKeyFromSession(session),
    });
  } catch (err) {
    console.log("FORREF_TEL clock=KEPT");
  }
}

export function telemetryView() {
  const host = matchTelemetry();
  if (!host) {
    return idleView();
  }
  try {
    return host.view();
  } catch (err) {
    return idleView();
  }
}

export function pulseTelemetry() {
  const host = matchTelemetry();
  if (!host) {
    return idleView();
  }
  try {
    return host.pulse();
  } catch (err) {
    return idleView();
  }
}

export function releaseMatchTelemetry() {
  const host = matchTelemetry();
  if (!host) {
    return;
  }
  try {
    host.release();
  } catch (err) {
    console.log("FORREF_TEL release=FAILED");
  }
}
