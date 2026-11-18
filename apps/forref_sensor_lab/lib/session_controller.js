// In-memory session. Sensor callbacks enqueue a bounded batch. They do not read storage.

import { measureSegment, MIN_SPEED_DT_MS, SPIKE_SPEED_MPS } from "./analytics.js";
import { attachGpsMeta, initialGps, reduceGps } from "./gps_state.js";
import { initialHr, reduceHr } from "./hr_state.js";

export const QUEUE_MAX = 32;
export const CHUNK_MAX = 16;

function blankCounters() {
  return {
    gpsCallbacks: 0,
    hrCallbacks: 0,
    gpsStartErrors: 0,
    hrStartErrors: 0,
    dropped: 0,
    rejected: 0,
    uncertified: 0,
    unflushed: 0,
    flushOk: 0,
    flushFail: 0,
    queueHighWater: 0,
    uiPaints: 0,
    latency: { lt20: 0, lt50: 0, lt100: 0, gte100: 0 },
    storageBytes: 0,
    maxCallbackMs: 0,
  };
}

export function createSession() {
  let phase = "PREPARING";
  let hr = initialHr();
  let gps = initialGps();
  let hrOnly = false;
  let recording = false;
  let preview = false;
  let sessionId = "";
  let anchor = null;
  let distanceMeters = 0;
  let gaps = 0;
  let recentSpeeds = [];
  let queue = [];
  let batteryPercent = null;
  let storageFull = false;
  let hrSampleAt = null;
  const counters = blankCounters();

  function rememberQueue() {
    counters.unflushed = queue.length;
    if (queue.length > counters.queueHighWater) {
      counters.queueHighWater = queue.length;
    }
  }

  function enqueue(record) {
    if (!recording) {
      return false;
    }
    if (queue.length >= QUEUE_MAX) {
      counters.dropped += 1;
      counters.uncertified += 1;
      if (!gps.gapOpen) {
        gps = Object.assign({}, gps, { gapOpen: true });
        gaps += 1;
      }
      rememberQueue();
      return false;
    }
    queue.push(record);
    rememberQueue();
    return true;
  }

  function noteSegment(next) {
    if (!anchor) {
      anchor = next;
      return;
    }
    const decision = measureSegment(anchor, next);
    if (decision.reason === "NON_POSITIVE_TIME" || decision.reason === "TELEPORT") {
      counters.rejected += 1;
      return;
    }
    if (decision.reason === "STATIONARY") {
      return;
    }
    const meters = decision.meters;
    const speed = decision.speed;
    const dt = decision.dt;
    const previous = recentSpeeds.length ? recentSpeeds[recentSpeeds.length - 1] : null;
    const isolated = recentSpeeds.length === 0 && speed > SPIKE_SPEED_MPS;
    const spike = isolated || (previous != null && speed > SPIKE_SPEED_MPS && speed > previous * 2);
    recentSpeeds.push(speed);
    if (recentSpeeds.length > 3) {
      recentSpeeds.shift();
    }
    anchor = next;
    if (spike || dt < MIN_SPEED_DT_MS) {
      return;
    }
    distanceMeters += meters;
  }

  function onGps(event) {
    counters.gpsCallbacks += 1;
    const beforeGap = gps.gapOpen;
    gps = reduceGps(gps, event);
    if (gps.gapOpen && !beforeGap) {
      gaps += 1;
    }
    if (!gps.accept || !recording || hrOnly) {
      return;
    }
    const point = { lat: event.lat, lon: event.lon, elapsedMs: event.elapsedMs };
    if (gps.bridge && anchor && !beforeGap) {
      noteSegment(point);
    } else {
      anchor = point;
    }
    enqueue({
      kind: "GNSS",
      sessionId: sessionId,
      elapsedMs: event.elapsedMs,
      gpsState: gps.state,
      accepted: 1,
      lat: event.lat,
      lon: event.lon,
    });
  }

  function onHr(bpm, elapsedMs) {
    counters.hrCallbacks += 1;
    hr = reduceHr(hr, { type: "sample", bpm: bpm });
    if (hr.live) {
      hrSampleAt = elapsedMs;
    }
    if (!recording) {
      return;
    }
    enqueue({
      kind: "HR",
      sessionId: sessionId,
      elapsedMs: elapsedMs,
      gpsState: gps.state,
      accepted: hr.live ? 1 : 0,
      hrBpm: hr.live ? hr.bpm : null,
    });
  }

  function tick(elapsedMs) {
    const age = hrSampleAt == null || typeof elapsedMs !== "number" ? null : elapsedMs - hrSampleAt;
    hr = reduceHr(hr, { type: "tick", sampleAgeMs: age });
    gps = reduceGps(gps, { type: "tick", elapsedMs: elapsedMs });
  }

  return {
    enableHr() {
      preview = true;
      hr = reduceHr(hr, { type: "init" });
      return { ok: true, phase: phase };
    },
    markMeasuring() {
      hr = reduceHr(hr, { type: "measuring" });
    },
    markHrPermission() {
      hr = reduceHr(hr, { type: "permission" });
    },
    markHrLast(bpm) {
      hr = reduceHr(hr, { type: "last", bpm: bpm });
    },
    markHrUnavailable() {
      hr = reduceHr(hr, { type: "sample", bpm: null });
    },
    startRecording(options) {
      hrOnly = !!(options && options.hrOnly);
      recording = true;
      preview = true;
      sessionId = options && options.sessionId ? options.sessionId : "";
      phase = hrOnly ? "READY_OR_HR_ONLY" : "RECORDING";
      if (hr.state === "STOPPED") {
        hr = reduceHr(hr, { type: "init" });
      }
      return { ok: true, phase: phase, sessionId: sessionId };
    },
    markGpsStart() {
      gps = reduceGps(gps, { type: "start" });
    },
    markGpsUnsupported() {
      gps = reduceGps(gps, { type: "unsupported" });
      if (recording) {
        phase = "READY_OR_HR_ONLY";
        hrOnly = true;
      }
    },
    markGpsPermission() {
      gps = reduceGps(gps, { type: "permission" });
      if (recording) {
        phase = "READY_OR_HR_ONLY";
        hrOnly = true;
      }
    },
    markGpsError() {
      counters.gpsStartErrors += 1;
      gps = reduceGps(gps, { type: "error" });
      phase = "ERROR_DEGRADED";
    },
    markHrError() {
      counters.hrStartErrors += 1;
      hr = reduceHr(hr, { type: "sample", bpm: null });
    },
    onGps: onGps,
    onHr: onHr,
    onGpsMeta(meta) {
      const beforeGap = gps.gapOpen;
      gps = attachGpsMeta(gps, meta || {});
      if (gps.gapOpen && !beforeGap) {
        gaps += 1;
      }
    },
    tick: tick,
    noteBattery(percent) {
      batteryPercent = typeof percent === "number" && isFinite(percent) ? percent : null;
    },
    noteLatency(ms) {
      if (typeof ms !== "number" || ms < 0) {
        return;
      }
      if (ms > counters.maxCallbackMs) {
        counters.maxCallbackMs = ms;
      }
      if (ms < 20) counters.latency.lt20 += 1;
      else if (ms < 50) counters.latency.lt50 += 1;
      else if (ms < 100) counters.latency.lt100 += 1;
      else counters.latency.gte100 += 1;
    },
    notePaint() {
      counters.uiPaints += 1;
    },
    takeBatch() {
      const batch = queue.splice(0, CHUNK_MAX);
      rememberQueue();
      return batch;
    },
    noteFlush(result) {
      if (result && result.ok) {
        counters.flushOk += 1;
        counters.storageBytes = result.bytes || counters.storageBytes;
        return;
      }
      counters.flushFail += 1;
      const lost = result && result.uncertified ? result.uncertified : 0;
      counters.uncertified += lost;
      if (result && result.reason === "CAPACITY") {
        storageFull = true;
      }
      phase = "ERROR_DEGRADED";
      if (!gps.gapOpen) {
        gps = Object.assign({}, gps, { gapOpen: true });
        gaps += 1;
      }
    },
    beginStop() {
      phase = "STOPPING";
    },
    finishStop() {
      recording = false;
      preview = false;
      phase = "STOPPED";
      hr = reduceHr(hr, { type: "stop" });
      gps = reduceGps(gps, { type: "stop" });
      counters.unflushed = queue.length;
    },
    queueLength() {
      return queue.length;
    },
    view() {
      return {
        phase: phase,
        sessionId: sessionId,
        hrState: hr.state,
        hrLive: hr.live,
        hrLastKnown: hr.lastKnown,
        hrBpm: hr.bpm,
        gpsState: gps.state,
        gpsAcquiring: gps.acquiring,
        hrOnly: hrOnly,
        distanceMeters: distanceMeters,
        distanceSaved: false,
        gaps: gaps,
        dropped: counters.dropped,
        uncertified: counters.uncertified,
        unflushed: queue.length,
        batteryPercent: batteryPercent,
        storageFull: storageFull,
        experimental: true,
      };
    },
    diagnostics() {
      return {
        phase: phase,
        sessionId: sessionId,
        gpsCallbacks: counters.gpsCallbacks,
        hrCallbacks: counters.hrCallbacks,
        gpsStartErrors: counters.gpsStartErrors,
        hrStartErrors: counters.hrStartErrors,
        dropped: counters.dropped,
        rejected: counters.rejected,
        uncertified: counters.uncertified,
        unflushed: queue.length,
        flushOk: counters.flushOk,
        flushFail: counters.flushFail,
        queueHighWater: counters.queueHighWater,
        uiPaints: counters.uiPaints,
        latency: counters.latency,
        storageBytes: counters.storageBytes,
        maxCallbackMs: counters.maxCallbackMs,
        batteryPercent: batteryPercent,
        gpsState: gps.state,
        hrState: hr.state,
        distanceSaved: false,
        experimental: true,
      };
    },
  };
}
