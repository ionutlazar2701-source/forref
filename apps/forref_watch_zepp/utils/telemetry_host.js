// App-scoped sensor binding. Callbacks update memory. They do not write storage or touch the clock.

function logTel(message) {
  console.log("FORREF_TEL " + message + " saved=0");
}

export function createTelemetryHost(sdk, engine, clock, timers) {
  let geo = null;
  let hr = null;
  let gpsOn = false;
  let hrOn = false;
  let persistTimer = null;
  let persistArmed = false;

  function elapsed() {
    try {
      return clock && clock.elapsed ? clock.elapsed() : 0;
    } catch (err) {
      return 0;
    }
  }

  function armPersist() {
    if (persistArmed || !timers || !engine.view().dirty) {
      return;
    }
    persistArmed = true;
    try {
      persistTimer = timers.set(() => {
        persistArmed = false;
        persistTimer = null;
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

  function readFix() {
    const status = geo.getStatus ? geo.getStatus() || "" : "";
    let lat = null;
    let lon = null;
    if (status === "A") {
      lat = geo.getLatitude();
      lon = geo.getLongitude();
    }
    let satellitesUsed = null;
    let metaPresent = false;
    try {
      if (geo.getGnssInfo) {
        const info = geo.getGnssInfo() || {};
        satellitesUsed = typeof info.nb_used_satellite === "number" ? info.nb_used_satellite : null;
        metaPresent = true;
      }
    } catch (err) {
      metaPresent = false;
    }
    engine.onGnss({
      status: status,
      lat: lat,
      lon: lon,
      elapsedMs: elapsed(),
      metaPresent: metaPresent,
      satellitesUsed: satellitesUsed,
    });
    armPersist();
  }

  function readHr() {
    let bpm = null;
    try {
      bpm = hr.getCurrent();
    } catch (err) {
      bpm = null;
    }
    engine.onHr({ type: "sample", bpm: bpm, elapsedMs: elapsed() });
  }

  function stopGps() {
    if (!gpsOn) {
      return;
    }
    try {
      if (geo && geo.offChange) {
        geo.offChange();
      }
    } catch (err) {
      logTel("gps=ERROR");
    }
    try {
      if (geo && geo.stop) {
        geo.stop();
      }
    } catch (err) {
      logTel("gps=ERROR");
    }
    gpsOn = false;
    try {
      engine.noteGps("stop");
    } catch (err) {
      logTel("gps=ERROR");
    }
  }

  function stopHr() {
    if (!hrOn) {
      return;
    }
    try {
      if (hr && hr.offCurrentChange) {
        hr.offCurrentChange();
      }
    } catch (err) {
      logTel("hr=ERROR");
    }
    try {
      if (hr && hr.stop) {
        hr.stop();
      }
    } catch (err) {
      logTel("hr=ERROR");
    }
    hrOn = false;
    try {
      engine.noteHr("stop");
    } catch (err) {
      logTel("hr=ERROR");
    }
  }

  function startGps() {
    if (gpsOn) {
      return;
    }
    try {
      if (!geo) {
        geo = new sdk.Geolocation();
      }
      if (sdk.checkSensor && sdk.Geolocation && sdk.checkSensor(sdk.Geolocation) === false) {
        engine.noteGps("unsupported");
        logTel("gps=UNSUPPORTED");
        return;
      }
      engine.noteGps("start");
      geo.onChange(() => {
        try {
          readFix();
        } catch (err) {
          engine.noteGps("error");
          logTel("gps=ERROR");
        }
      });
      geo.start();
      gpsOn = true;
      logTel("gps=SEARCHING");
    } catch (err) {
      gpsOn = false;
      try {
        if (geo && geo.offChange) {
          geo.offChange();
        }
      } catch (inner) {
        logTel("gps=ERROR");
      }
      try {
        engine.noteGps("error");
      } catch (inner) {
        logTel("gps=ERROR");
      }
      logTel("gps=ERROR");
    }
  }

  function startHr() {
    if (hrOn) {
      return;
    }
    try {
      if (!hr) {
        hr = new sdk.HeartRate();
      }
      engine.noteHr("measuring");
      hr.onCurrentChange(() => {
        try {
          readHr();
        } catch (err) {
          logTel("hr=ERROR");
        }
      });
      if (hr.start) {
        hr.start();
      }
      hrOn = true;
      logTel("hr=MEASURING");
    } catch (err) {
      hrOn = false;
      try {
        engine.noteHr("error");
      } catch (inner) {
        logTel("hr=ERROR");
      }
      logTel("hr=ERROR");
    }
  }

  function sync() {
    let demand = { gps: false, hr: false, release: false };
    try {
      demand = engine.demand();
    } catch (err) {
      logTel("sync=FAILED");
      return;
    }
    if (demand.release) {
      stopGps();
      stopHr();
      return;
    }
    if (demand.gps) {
      if (gpsOn && engine.view().gpsState === "STOPPED") {
        stopGps();
      }
      startGps();
    } else {
      stopGps();
    }
    if (demand.hr) {
      if (hrOn && engine.view().hrState === "STOPPED") {
        stopHr();
      }
      startHr();
    } else {
      stopHr();
    }
  }

  function followClock(info) {
    try {
      engine.afterClock(info || {});
      sync();
    } catch (err) {
      logTel("clock=KEPT");
    }
  }

  function release() {
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

  return {
    followClock: followClock,
    release: release,
    sync: sync,
    pulse: function () {
      try {
        return engine.pulse(elapsed());
      } catch (err) {
        return engine.view();
      }
    },
    view: function () {
      return engine.view();
    },
    listenerCounts: function () {
      return { gps: gpsOn ? 1 : 0, hr: hrOn ? 1 : 0 };
    },
    pageExit: function () {},
  };
}
