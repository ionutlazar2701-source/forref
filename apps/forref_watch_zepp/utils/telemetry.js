// Experimental match telemetry. Not Match Memory, not D1, and not a saved distance.
// The match clock decides the phase. This module only accounts meters after that.

import { advanceDistance } from "../../forref_sensor_lab/lib/analytics.js";
import { initialGps, reduceGps } from "../../forref_sensor_lab/lib/gps_state.js";
import { initialHr, reduceHr } from "../../forref_sensor_lab/lib/hr_state.js";

const KEY = "__FORREF_MATCH_TELEMETRY__";
const ACTIVE = {
  FIRST_HALF_RUNNING: "first",
  SECOND_HALF_RUNNING: "second",
};

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
  return "hrNone";
}

export function gpsStatusKey(state) {
  if (state === "READY") return "gpsReady";
  if (state === "RECOVERED") return "gpsBack";
  if (state === "SEARCHING") return "gpsSearch";
  if (state === "WEAK_OR_STALE") return "gpsWeak";
  if (state === "LOST") return "gpsLost";
  if (state === "STOPPED") return "gpsOff";
  return "gpsNone";
}

function idleView() {
  return {
    distanceMeters: 0,
    firstMeters: 0,
    secondMeters: 0,
    hrState: "STOPPED",
    gpsState: "STOPPED",
    experimental: true,
    distanceSaved: false,
    official: false,
    uncertified: 0,
    released: false,
    openHalf: null,
    dirty: false,
  };
}

function activeHalf(phase, trust) {
  if (trust === "TIME_UNVERIFIED") {
    return null;
  }
  return ACTIVE[phase] || null;
}

function parseStore(text) {
  if (!text) {
    return null;
  }
  const parts = String(text).split("|");
  if (parts.length !== 5 || parts[0] !== "T1") {
    return { corrupt: true };
  }
  const first = Number(parts[2]);
  const second = Number(parts[3]);
  const flag = Number(parts[4]);
  if (!isFinite(first) || !isFinite(second) || first < 0 || second < 0 || !isFinite(flag) || flag < 0) {
    return { corrupt: true };
  }
  return { first: first / 1000, second: second / 1000, uncertified: flag, corrupt: false };
}

export function createMatchTelemetry(options) {
  const store = options && options.store ? options.store : null;
  let epoch = options && options.epoch ? options.epoch : "";
  let phase = "READY";
  let trust = "FROZEN_OBSERVED";
  let firstMeters = 0;
  let secondMeters = 0;
  let anchor = null;
  let recentSpeeds = [];
  let needAnchor = true;
  let openHalf = null;
  let gps = initialGps();
  let hr = initialHr();
  let uncertified = 0;
  let released = false;
  let dirty = false;
  let pending = null;
  let sawStoreFault = false;
  let hrMark = null;

  if (store) {
    try {
      const parsed = parseStore(store.read());
      if (parsed && parsed.corrupt) {
        uncertified += 1;
      } else if (parsed) {
        pending = parsed;
      }
    } catch (err) {
      uncertified += 1;
    }
  }

  function view() {
    return {
      distanceMeters: firstMeters + secondMeters,
      firstMeters: firstMeters,
      secondMeters: secondMeters,
      hrState: hr.state,
      gpsState: gps.state,
      experimental: true,
      distanceSaved: false,
      official: false,
      uncertified: uncertified,
      released: released,
      openHalf: openHalf,
      dirty: dirty,
      epoch: epoch,
    };
  }

  function payload() {
    return "T1|" + epoch + "|" + Math.round(firstMeters * 1000) + "|" + Math.round(secondMeters * 1000) + "|" + uncertified;
  }

  function persist() {
    if (!store) {
      dirty = false;
      return { ok: true, skipped: true };
    }
    const line = payload();
    try {
      const result = store.write(line);
      if (!result || result.ok === false) {
        if (!sawStoreFault) {
          uncertified += 1;
          sawStoreFault = true;
        }
        return { ok: false, reason: result && result.reason ? result.reason : "UNVERIFIED" };
      }
      dirty = false;
      sawStoreFault = false;
      return { ok: true };
    } catch (err) {
      if (!sawStoreFault) {
        uncertified += 1;
        sawStoreFault = true;
      }
      return { ok: false, reason: "WRITE_FAILED" };
    }
  }

  function closeSegment() {
    anchor = null;
    recentSpeeds = [];
    needAnchor = true;
    openHalf = null;
  }

  function resetMatch() {
    firstMeters = 0;
    secondMeters = 0;
    uncertified = 0;
    pending = null;
    sawStoreFault = false;
    dirty = true;
    closeSegment();
    gps = initialGps();
    hr = initialHr();
    released = false;
  }

  function applyPending() {
    if (!pending || pending.corrupt) {
      pending = null;
      return;
    }
    firstMeters = pending.first;
    secondMeters = pending.second;
    uncertified = pending.uncertified;
    pending = null;
    needAnchor = true;
    anchor = null;
  }

  function afterClock(info) {
    const next = info || {};
    const boot = next.boot === true;
    const nextEpoch = next.epoch || epoch;
    const epochChanged = !!(epoch && nextEpoch && nextEpoch !== epoch);
    if (!boot && epochChanged) {
      persist();
      resetMatch();
    }
    if (!boot && !epochChanged && next.phase === phase && next.trust === trust) {
      epoch = nextEpoch || epoch;
      return view();
    }
    epoch = nextEpoch || epoch;
    if (boot) {
      phase = next.phase || phase;
      trust = next.trust || trust;
      if (phase === "READY") {
        firstMeters = 0;
        secondMeters = 0;
        closeSegment();
        return view();
      }
      applyPending();
      closeSegment();
      released = phase === "FULL_TIME" || phase === "ABANDONED";
      openHalf = activeHalf(phase, trust);
      needAnchor = true;
      return view();
    }
    const previous = phase;
    if (previous === "READY" && next.phase === "FIRST_HALF_RUNNING") {
      resetMatch();
      epoch = nextEpoch || epoch;
    }
    const leaving = openHalf;
    phase = next.phase || phase;
    trust = next.trust || trust;
    const nextOpen = activeHalf(phase, trust);
    if (leaving && leaving !== nextOpen) {
      closeSegment();
    }
    if (!nextOpen) {
      closeSegment();
    } else if (leaving !== nextOpen) {
      anchor = null;
      recentSpeeds = [];
      needAnchor = true;
      openHalf = nextOpen;
    }
    released = phase === "FULL_TIME" || phase === "ABANDONED";
    dirty = true;
    persist();
    return view();
  }

  function onGnss(sample) {
    if (released) {
      return view();
    }
    const body = sample || {};
    const elapsed = typeof body.elapsedMs === "number" ? body.elapsedMs : 0;
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
      return view();
    }
    const step = advanceDistance(anchor, recentSpeeds, point);
    anchor = step.anchor;
    recentSpeeds = step.recentSpeeds;
    if (step.added > 0 && openHalf === "first") {
      firstMeters += step.added;
      dirty = true;
    } else if (step.added > 0 && openHalf === "second") {
      secondMeters += step.added;
      dirty = true;
    }
    return view();
  }

  function onHr(event) {
    if (released) {
      return view();
    }
    if (event && event.type === "sample" && typeof event.elapsedMs === "number") {
      hrMark = event.elapsedMs;
    }
    hr = reduceHr(hr, event);
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
    closeSegment();
    released = true;
    gps = reduceGps(gps, { type: "stop" });
    hr = reduceHr(hr, { type: "stop" });
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
