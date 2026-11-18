// Sensor host. Callbacks update memory and arm a timer. They do not read the journal.

import { createChunkStore } from "./chunk_store.js";
import { createSession } from "./session_controller.js";

function logLine(message) {
  console.log("FORREF_SENS_V2 " + message + " d1=UNCERTIFIED");
}

export function createSensorHost(sdk, adapter, clock, timers) {
  const session = createSession();
  const store = createChunkStore(adapter);
  const geo = new sdk.Geolocation();
  const hr = new sdk.HeartRate();
  let battery = null;
  try {
    battery = sdk.Battery ? new sdk.Battery() : null;
  } catch (err) {
    battery = null;
  }
  let gpsListening = false;
  let hrListening = false;
  let displayListening = false;
  let flushTimer = null;
  let flushArmed = false;
  let startedGps = false;
  let released = false;

  function elapsed() {
    try {
      return clock.elapsed();
    } catch (err) {
      return 0;
    }
  }

  function armFlush() {
    if (flushArmed || !timers || released) {
      return;
    }
    flushArmed = true;
    flushTimer = timers.set(() => {
      flushArmed = false;
      flushTimer = null;
      flush();
    }, 1000);
  }

  function flush() {
    const batch = session.takeBatch();
    if (batch.length === 0) {
      return { ok: true, empty: true };
    }
    const result = store.flush(session.view().sessionId, batch);
    session.noteFlush(result);
    if (!result.ok) {
      logLine("flush=0 reason=" + (result.reason || "UNVERIFIED") + " lost=" + (result.uncertified || 0));
    } else {
      logLine("flush=1 bytes=" + (result.bytes || 0) + " saved=0");
    }
    return result;
  }

  function onGps() {
    const started = elapsed();
    try {
      const status = geo.getStatus() || "";
      let lat = null;
      let lon = null;
      if (status === "A") {
        lat = geo.getLatitude();
        lon = geo.getLongitude();
      }
      session.onGps({ type: "sample", status: status, lat: lat, lon: lon, elapsedMs: elapsed(), metaPresent: false });
    } catch (err) {
      session.markGpsError();
      logLine("gps=ERROR");
    }
    session.noteLatency(elapsed() - started);
    armFlush();
  }

  function onGnssInfo(info) {
    const body = info || {};
    session.onGpsMeta({
      satellitesUsed: typeof body.nb_used_satellite === "number" ? body.nb_used_satellite : null,
      satellitesValid: typeof body.nb_valid_satellite === "number" ? body.nb_valid_satellite : null,
      signal: typeof body.top4_cn_val === "number" ? body.top4_cn_val : null,
      agpsTimestamp: typeof body.agps_timestamp === "number" ? body.agps_timestamp : null,
    });
  }

  function onHeart() {
    const started = elapsed();
    let bpm = null;
    try {
      bpm = hr.getCurrent();
    } catch (err) {
      bpm = null;
    }
    session.onHr(bpm, elapsed());
    session.noteLatency(elapsed() - started);
    armFlush();
  }

  function onDisplay(status) {
    const raw = status == null ? "" : String(status);
    const off = raw === "0" || raw.toLowerCase() === "off";
    logLine("display=" + (off ? "OFF" : "OTHER"));
  }

  function ensureHr() {
    if (hrListening) {
      return { ok: true, already: true };
    }
    session.markMeasuring();
    try {
      hr.onCurrentChange(onHeart);
      hrListening = true;
    } catch (err) {
      session.markHrError();
      logLine("hr=UNAVAILABLE");
      return { ok: false, reason: "HR_UNAVAILABLE" };
    }
    try {
      if (!session.view().hrLive && hr.getLast) {
        session.markHrLast(hr.getLast());
      }
    } catch (err) {
      session.markHrUnavailable();
    }
    logLine("hr=ON gps=" + session.view().gpsState);
    return { ok: true };
  }

  function ensureGps() {
    if (gpsListening || startedGps) {
      return { ok: true, already: true };
    }
    let supported = true;
    try {
      if (sdk.checkSensor) {
        supported = sdk.checkSensor(sdk.Geolocation) !== false;
      }
    } catch (err) {
      supported = false;
    }
    if (!supported) {
      session.markGpsUnsupported();
      logLine("gps=UNSUPPORTED");
      return { ok: false, reason: "UNSUPPORTED" };
    }
    let enabled = true;
    try {
      if (geo.getEnabled) {
        enabled = geo.getEnabled() !== false;
      }
    } catch (err) {
      enabled = false;
    }
    if (!enabled) {
      session.markGpsPermission();
      logLine("gps=PERMISSION_REQUIRED");
      return { ok: false, reason: "PERMISSION_REQUIRED" };
    }
    try {
      geo.onChange(onGps);
      gpsListening = true;
      if (geo.onGnssChange) {
        geo.onGnssChange(onGnssInfo);
      }
      geo.start();
      startedGps = true;
      session.markGpsStart();
    } catch (err) {
      try {
        if (geo.offChange) geo.offChange(onGps);
      } catch (stopErr) {
        session.markGpsError();
      }
      gpsListening = false;
      startedGps = false;
      session.markGpsError();
      logLine("gps=ERROR");
      return { ok: false, reason: "ERROR" };
    }
    logLine("gps=SEARCHING");
    return { ok: true };
  }

  function enableHr() {
    if (released) {
      return { ok: false, reason: "RELEASED" };
    }
    session.enableHr();
    watchDisplay();
    return ensureHr();
  }

  function startSession(options) {
    if (released) {
      return { ok: false, reason: "RELEASED" };
    }
    const hrOnly = !!(options && options.hrOnly);
    const allocated = store.nextSessionId();
    const sessionId = allocated.ok ? allocated.sessionId : "V2-UNVERIFIED";
    session.startRecording({ hrOnly: hrOnly || !allocated.ok, sessionId: sessionId });
    watchDisplay();
    const hrResult = ensureHr();
    let gpsResult = { ok: false, reason: "HR_ONLY" };
    if (!hrOnly) {
      gpsResult = ensureGps();
    } else {
      logLine("mode=HR_ONLY gps=OFF");
    }
    if (!allocated.ok) {
      session.noteFlush({ ok: false, reason: "UNVERIFIED", uncertified: 0 });
    }
    logLine("session=" + sessionId + " phase=" + session.view().phase);
    return { ok: hrResult.ok || gpsResult.ok || hrOnly, sessionId: sessionId, gps: session.view().gpsState, hr: session.view().hrState };
  }

  function detach() {
    if (flushTimer != null && timers) {
      timers.clear(flushTimer);
      flushTimer = null;
    }
    flushArmed = false;
    if (gpsListening) {
      try {
        if (geo.offChange) geo.offChange(onGps);
      } catch (err) {
        session.markGpsError();
      }
      try {
        if (geo.offGnssChange) geo.offGnssChange(onGnssInfo);
      } catch (err) {
        session.markGpsError();
      }
      gpsListening = false;
    }
    if (startedGps) {
      try {
        geo.stop();
      } catch (err) {
        session.markGpsError();
      }
      startedGps = false;
    }
    if (hrListening) {
      try {
        if (hr.offCurrentChange) hr.offCurrentChange(onHeart);
      } catch (err) {
        session.markHrError();
      }
      hrListening = false;
    }
    if (displayListening && sdk.display && sdk.display.offStatusChange) {
      try {
        sdk.display.offStatusChange(onDisplay);
      } catch (err) {
        logLine("display=STOP_FAILED");
      }
      displayListening = false;
    }
  }

  function stop() {
    session.beginStop();
    detach();
    flush();
    session.finishStop();
    globalThis.__FORREF_SENS_DIAG = session.diagnostics();
    logLine("session=STOPPED gps=STOPPED hr=STOPPED");
    return { ok: true, saved: false };
  }

  function release() {
    if (released) {
      return { ok: true, already: true };
    }
    stop();
    released = true;
    return { ok: true };
  }

  function watchDisplay() {
    if (displayListening || !sdk.display || !sdk.display.onStatusChange) {
      return;
    }
    try {
      sdk.display.onStatusChange(onDisplay);
      displayListening = true;
    } catch (err) {
      displayListening = false;
    }
  }

  function sampleBattery() {
    if (!battery || !battery.getCurrent) {
      return null;
    }
    try {
      const value = battery.getCurrent();
      session.noteBattery(typeof value === "number" ? value : null);
    } catch (err) {
      session.noteBattery(null);
    }
    return session.view().batteryPercent;
  }

  globalThis.__FORREF_SENS_RELEASE = release;

  return {
    enableHr: enableHr,
    startSession: startSession,
    stop: stop,
    release: release,
    flush: flush,
    tick: (ms) => session.tick(ms),
    sampleBattery: sampleBattery,
    view: () => session.view(),
    diagnostics: () => session.diagnostics(),
    markPaint() {
      session.notePaint();
    },
    listeners: () => ({ gps: gpsListening ? 1 : 0, hr: hrListening ? 1 : 0, gpsStarted: startedGps ? 1 : 0 }),
  };
}

export function readPerformance(sdk) {
  try {
    if (!sdk || !sdk.getPerformance) {
      return { available: false };
    }
    const raw = sdk.getPerformance() || {};
    const out = { available: true };
    ["memory", "cpu", "fps"].forEach((key) => {
      if (typeof raw[key] === "number" && isFinite(raw[key])) {
        out[key] = raw[key];
      }
    });
    return out;
  } catch (err) {
    return { available: false };
  }
}
