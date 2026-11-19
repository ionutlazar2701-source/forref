// App-scoped sensor binding. Clock admission stays in memory.
// SDK constructors, listener registration, and storage run only from the deferred turn.

function logTel(message) {
  console.log("FORREF_TEL " + message + " saved=0");
}

function usableBpm(bpm) {
  return typeof bpm === "number" && isFinite(bpm) && bpm >= 30 && bpm <= 230;
}

export function createTelemetryHost(sdk, engine, clock, timers) {
  let geo = null;
  let hr = null;
  let gpsOn = false;
  let hrOn = false;
  let gpsStarting = false;
  let hrStarting = false;
  let gpsLeaked = false;
  let hrLeaked = false;
  let gpsHold = "";
  let hrHold = "";
  let degraded = false;
  let cancelled = false;
  let queued = false;
  let boundGpsToken = 0;
  let hrToken = 0;
  let activeGpsCallback = null;
  let activeGnssCallback = null;
  let activeHrCallback = null;
  let persistTimer = null;
  let persistArmed = false;
  const queue = [];
  let gnssMeta = {
    metaPresent: false,
    satellitesUsed: null,
    satellitesValid: null,
    signal: null,
    agpsTimestamp: null,
  };

  function elapsed() {
    try {
      const value = clock && clock.elapsed ? clock.elapsed() : 0;
      return typeof value === "number" && isFinite(value) ? value : null;
    } catch (err) {
      return null;
    }
  }

  function armPersist() {
    if (persistArmed || cancelled || !timers || !engine.view().dirty) {
      return;
    }
    persistArmed = true;
    try {
      persistTimer = timers.set(function () {
        persistArmed = false;
        persistTimer = null;
        if (cancelled) {
          return;
        }
        try {
          engine.flush();
        } catch (err) {
          logTel("store=FAILED");
        }
      }, 5000);
    } catch (err) {
      persistArmed = false;
      logTel("store=FAILED");
    }
  }

  function unsubscribe(target, method, callback) {
    try {
      if (target && typeof target[method] === "function") {
        target[method](callback);
      }
      return true;
    } catch (err) {
      degraded = true;
      logTel("unbind=FAILED");
      return false;
    }
  }

  function rememberGnss(info) {
    const body = info || {};
    gnssMeta = {
      metaPresent: true,
      satellitesUsed: typeof body.nb_used_satellite === "number" ? body.nb_used_satellite : null,
      satellitesValid: typeof body.nb_valid_satellite === "number" ? body.nb_valid_satellite : null,
      signal: typeof body.top4_cn_val === "number" ? body.top4_cn_val : null,
      agpsTimestamp: typeof body.agps_timestamp === "number" ? body.agps_timestamp : null,
    };
  }

  function readFix(token) {
    const now = elapsed();
    if (!gpsOn || token !== boundGpsToken || engine.captureToken() !== token) {
      return;
    }
    const status = geo && geo.getStatus ? geo.getStatus() || "" : "";
    let lat = null;
    let lon = null;
    if (status === "A" && geo) {
      lat = geo.getLatitude();
      lon = geo.getLongitude();
    }
    let meta = gnssMeta;
    try {
      if (geo && geo.getGnssInfo) {
        const info = geo.getGnssInfo() || {};
        meta = {
          metaPresent: true,
          satellitesUsed: typeof info.nb_used_satellite === "number" ? info.nb_used_satellite : null,
          satellitesValid: typeof info.nb_valid_satellite === "number" ? info.nb_valid_satellite : null,
          signal: typeof info.top4_cn_val === "number" ? info.top4_cn_val : null,
          agpsTimestamp: typeof info.agps_timestamp === "number" ? info.agps_timestamp : null,
        };
        gnssMeta = meta;
      }
    } catch (err) {
      meta = { metaPresent: false, satellitesUsed: null, satellitesValid: null, signal: null, agpsTimestamp: null };
    }
    engine.onGnss({
      status: status,
      lat: lat,
      lon: lon,
      elapsedMs: now,
      observedAtMs: now,
      generation: token,
      provenance: now == null ? "UNCERTAIN" : "DELIVERY",
      metaPresent: meta.metaPresent === true,
      satellitesUsed: meta.satellitesUsed,
      satellitesValid: meta.satellitesValid,
      signal: meta.signal,
      agpsTimestamp: meta.agpsTimestamp,
    });
    armPersist();
  }

  function readHr(token) {
    if (!hrOn || token !== hrToken) {
      return;
    }
    let bpm = null;
    try {
      bpm = hr.getCurrent();
    } catch (err) {
      bpm = null;
    }
    const now = elapsed();
    engine.onHr({
      type: "sample",
      bpm: bpm,
      elapsedMs: now == null ? null : now,
    });
  }

  function stopGps() {
    if (!gpsOn && !gpsLeaked) {
      gpsHold = "";
      return;
    }
    gpsHold = "";
    gpsOn = false;
    boundGpsToken = -1;
    const removedChange = unsubscribe(geo, "offChange", activeGpsCallback);
    const removedInfo = unsubscribe(geo, "offGnssChange", activeGnssCallback);
    activeGpsCallback = null;
    activeGnssCallback = null;
    if (!removedChange || !removedInfo) {
      gpsLeaked = true;
    } else {
      gpsLeaked = false;
    }
    try {
      if (geo && geo.stop) {
        geo.stop();
      }
    } catch (err) {
      degraded = true;
      logTel("gps=ERROR");
    }
    gnssMeta = { metaPresent: false, satellitesUsed: null, satellitesValid: null, signal: null, agpsTimestamp: null };
    try {
      engine.noteGps("stop");
    } catch (err) {
      logTel("gps=ERROR");
    }
  }

  function stopHr() {
    if (!hrOn && !hrLeaked) {
      hrHold = "";
      return;
    }
    hrHold = "";
    hrOn = false;
    hrToken += 1;
    const removed = unsubscribe(hr, "offCurrentChange", activeHrCallback);
    activeHrCallback = null;
    hrLeaked = !removed;
    try {
      engine.noteHr("stop");
    } catch (err) {
      logTel("hr=ERROR");
    }
  }

  function startGps() {
    if (cancelled || gpsStarting) {
      return;
    }
    if (gpsOn && boundGpsToken !== engine.captureToken()) {
      stopGps();
    }
    if (gpsOn || gpsLeaked || gpsHold) {
      return;
    }
    gpsStarting = true;
    let subscribed = false;
    try {
      if (sdk.checkSensor && sdk.Geolocation && sdk.checkSensor(sdk.Geolocation) === false) {
        gpsHold = "unsupported";
        engine.noteGps("unsupported");
        logTel("gps=UNSUPPORTED");
        return;
      }
      if (!geo) {
        geo = new sdk.Geolocation();
      }
      if (geo.getEnabled && geo.getEnabled() === false) {
        gpsHold = "permission";
        engine.noteGps("permission");
        logTel("gps=PERMISSION");
        return;
      }
      engine.noteGps("start");
      const token = engine.captureToken();
      boundGpsToken = token;
      activeGpsCallback = function onGpsChange() {
        if (!gpsOn || engine.captureToken() !== token) {
          return;
        }
        try {
          readFix(token);
        } catch (err) {
          try {
            engine.noteGps("error");
          } catch (inner) {
            logTel("gps=ERROR");
          }
          logTel("gps=ERROR");
        }
      };
      activeGnssCallback = function onGnssInfo(info) {
        if (!gpsOn || engine.captureToken() !== token) {
          return;
        }
        rememberGnss(info);
      };
      subscribed = true;
      geo.onChange(activeGpsCallback);
      if (geo.onGnssChange) {
        geo.onGnssChange(activeGnssCallback);
      }
      gpsOn = true;
      geo.start();
      gpsHold = "";
      logTel("gps=SEARCHING");
    } catch (err) {
      gpsOn = false;
      gpsHold = "error";
      if (subscribed) {
        const removed = unsubscribe(geo, "offChange", activeGpsCallback);
        unsubscribe(geo, "offGnssChange", activeGnssCallback);
        gpsLeaked = !removed;
      }
      try {
        engine.noteGps("error");
      } catch (inner) {
        logTel("gps=ERROR");
      }
      logTel("gps=ERROR");
    } finally {
      gpsStarting = false;
    }
  }

  function seedLastKnown() {
    if (!hr || !hr.getLast) {
      return;
    }
    let bpm = null;
    try {
      bpm = hr.getLast();
    } catch (err) {
      return;
    }
    if (!usableBpm(bpm)) {
      return;
    }
    if (engine.view().hrFresh) {
      return;
    }
    engine.onHr({ type: "last", bpm: bpm });
  }

  function startHr() {
    if (cancelled || hrOn || hrStarting || hrLeaked || hrHold) {
      return;
    }
    hrStarting = true;
    let subscribed = false;
    try {
      if (sdk.checkSensor && sdk.HeartRate && sdk.checkSensor(sdk.HeartRate) === false) {
        hrHold = "unsupported";
        engine.noteHr("error");
        logTel("hr=UNAVAILABLE");
        return;
      }
      if (!hr) {
        hr = new sdk.HeartRate();
      }
      const token = hrToken;
      engine.noteHr("measuring");
      activeHrCallback = function onHrChange() {
        if (!hrOn || token !== hrToken) {
          return;
        }
        try {
          readHr(token);
        } catch (err) {
          logTel("hr=ERROR");
        }
      };
      hrOn = true;
      subscribed = true;
      hr.onCurrentChange(activeHrCallback);
      hrHold = "";
      seedLastKnown();
      logTel("hr=MEASURING");
    } catch (err) {
      hrOn = false;
      hrHold = "error";
      if (subscribed) {
        hrLeaked = !unsubscribe(hr, "offCurrentChange", activeHrCallback);
      }
      try {
        engine.noteHr("error");
      } catch (inner) {
        logTel("hr=ERROR");
      }
      logTel("hr=ERROR");
    } finally {
      hrStarting = false;
    }
  }

  function sync() {
    if (cancelled) {
      return;
    }
    let demand = { gps: false, hr: false, release: false };
    try {
      demand = engine.demand();
    } catch (err) {
      logTel("sync=FAILED");
      return;
    }
    try {
      engine.flush();
    } catch (err) {
      logTel("store=FAILED");
    }
    if (demand.release) {
      stopGps();
      stopHr();
      return;
    }
    if (demand.gps) {
      startGps();
    } else {
      stopGps();
    }
    if (demand.hr) {
      startHr();
    } else {
      stopHr();
    }
  }

  function scheduleDevices() {
    if (cancelled || queued) {
      return;
    }
    queued = true;
    const run = function () {
      queued = false;
      if (cancelled) {
        return;
      }
      try {
        sync();
      } catch (err) {
        logTel("sync=FAILED");
      }
    };
    if (timers && typeof timers.defer === "function") {
      try {
        timers.defer(run);
        return;
      } catch (err) {
        queued = false;
        logTel("defer=FAILED");
        return;
      }
    }
    queue.push(run);
  }

  function followClock(info) {
    const raw = info || {};
    const opened = typeof raw.openedAtMs === "number" && isFinite(raw.openedAtMs) ? raw.openedAtMs : elapsed();
    try {
      engine.afterClock({
        epoch: raw.epoch,
        phase: raw.phase,
        trust: raw.trust,
        boot: raw.boot === true,
        matchKey: raw.matchKey,
        openedAtMs: opened,
      });
    } catch (err) {
      logTel("clock=KEPT");
      return;
    }
    scheduleDevices();
  }

  function release() {
    cancelled = true;
    queued = false;
    queue.length = 0;
    try {
      if (timers && persistTimer != null && timers.clear) {
        timers.clear(persistTimer);
      }
    } catch (err) {
      logTel("store=FAILED");
    }
    persistArmed = false;
    persistTimer = null;
    stopGps();
    stopHr();
    try {
      engine.release();
    } catch (err) {
      logTel("release=FAILED");
    }
  }

  function needsDevices() {
    let demand;
    try {
      demand = engine.demand();
    } catch (err) {
      return false;
    }
    if (demand.release) {
      return gpsOn || hrOn;
    }
    if (demand.gps && !gpsOn && !gpsLeaked && !gpsHold && !gpsStarting) {
      return true;
    }
    if (demand.hr && !hrOn && !hrLeaked && !hrHold && !hrStarting) {
      return true;
    }
    return false;
  }

  return {
    followClock: followClock,
    release: release,
    sync: sync,
    drain: function () {
      const batch = queue.splice(0, queue.length);
      for (let i = 0; i < batch.length; i++) {
        batch[i]();
      }
    },
    pulse: function () {
      let view;
      try {
        const now = elapsed();
        view = engine.pulse(now == null ? 0 : now);
      } catch (err) {
        view = engine.view();
      }
      if (!queued && !cancelled && needsDevices()) {
        scheduleDevices();
      }
      return view;
    },
    view: function () {
      return engine.view();
    },
    listenerCounts: function () {
      return {
        gps: gpsOn || gpsLeaked ? 1 : 0,
        hr: hrOn || hrLeaked ? 1 : 0,
        degraded: degraded,
      };
    },
    handles: function () {
      return { gps: activeGpsCallback, hr: activeHrCallback, gnss: activeGnssCallback };
    },
    pageExit: function () {},
  };
}
