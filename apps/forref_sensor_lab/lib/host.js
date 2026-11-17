// Foreground sensor session. Geolocation stays here. App Service cannot run it.

import { GAP_MS } from "./analytics.js";

function numberOrNull(value) {
  return typeof value === "number" && isFinite(value) ? value : null;
}

function logSample(entry) {
  const flags = entry.flags && entry.flags.length ? entry.flags.join(",") : "";
  console.log(
    "FORREF_SENS kind=" + entry.kind +
    " name=" + (entry.name || "") +
    " seq=" + (entry.seq == null ? "" : entry.seq) +
    " status=" + (entry.gpsStatus || "") +
    " flags=" + flags +
    " gap=" + (entry.gapReason || "") +
    " d1=UNCERTIFIED"
  );
}

export function createSensorHost(sdk, journal, clock) {
  const geo = new sdk.Geolocation();
  const hr = new sdk.HeartRate();
  let distance = null;
  let battery = null;
  try {
    distance = sdk.Distance ? new sdk.Distance() : null;
  } catch (err) {
    distance = null;
  }
  try {
    battery = sdk.Battery ? new sdk.Battery() : null;
  } catch (err) {
    battery = null;
  }
  let gnssCb = null;
  let gnssInfoCb = null;
  let hrCb = null;
  let distCb = null;
  let displayCb = null;
  let running = false;
  let sessionId = "";
  let lastSignal = null;
  let lastSatellites = null;
  let lastError = "";

  function stamp() {
    return {
      diagnosticElapsedMs: clock.elapsed(),
      diagnosticUtcMs: clock.utc(),
      sessionId: sessionId,
      source: "DEVICE_APP",
    };
  }

  function store(record) {
    const result = journal.append(Object.assign(stamp(), record));
    if (result.entry) {
      logSample(result.entry);
    } else {
      lastError = result.reason || "WRITE_FAILED";
      console.log("FORREF_SENS kind=" + (record.kind || "") + " stored=0 reason=" + lastError + " d1=UNCERTIFIED");
    }
    return result;
  }

  function lastGnss() {
    const loaded = journal.read();
    if (!loaded.ok) {
      return null;
    }
    const rows = loaded.entries.filter((entry) => entry.kind === "GNSS" && entry.sessionId === sessionId);
    return rows.length ? rows[rows.length - 1] : null;
  }

  function onGnss() {
    let status = "";
    try {
      status = geo.getStatus() || "";
    } catch (err) {
      status = "";
    }
    const fix = status === "A";
    let lat = null;
    let lon = null;
    if (fix) {
      try {
        lat = numberOrNull(geo.getLatitude());
        lon = numberOrNull(geo.getLongitude());
      } catch (err) {
        lat = null;
        lon = null;
      }
    }
    const flags = [];
    if (!fix) {
      flags.push("NO_FIX");
    }
    const prev = lastGnss();
    const elapsed = clock.elapsed();
    if (prev && prev.diagnosticElapsedMs != null && elapsed != null && elapsed < prev.diagnosticElapsedMs) {
      store({ kind: "GAP", gapReason: "RESTART_UNMEASURED", missingMs: null, fromSeq: prev.seq, flags: ["UNMEASURED"] });
    } else if (prev && prev.diagnosticElapsedMs != null && elapsed != null && elapsed - prev.diagnosticElapsedMs > GAP_MS) {
      const loaded = journal.read();
      const between = loaded.ok ? loaded.entries.filter((entry) => entry.seq > prev.seq && entry.kind === "LIFECYCLE" && (entry.name === "DISPLAY_OFF" || entry.name === "PAUSE")) : [];
      store({
        kind: "GAP",
        gapReason: between.length ? "SCREEN_OFF_OR_PAUSE" : "STALL",
        missingMs: elapsed - prev.diagnosticElapsedMs,
        fromSeq: prev.seq,
        flags: [],
      });
    }
    const batteryPercent = battery && battery.getCurrent ? numberOrNull(battery.getCurrent()) : null;
    const stored = store({
      kind: "GNSS",
      gpsStatus: status || "UNAVAILABLE",
      lat: lat,
      lon: lon,
      satellites: lastSatellites,
      signal: lastSignal,
      batteryPercent: batteryPercent,
      flags: flags,
    });
    if (!stored.ok && stored.reason === "CAPACITY") {
      stop();
    }
  }

  function onHr() {
    let bpm = null;
    try {
      bpm = numberOrNull(hr.getCurrent());
    } catch (err) {
      bpm = null;
    }
    const flags = bpm == null ? ["HR_UNAVAILABLE"] : [];
    store({ kind: "HR", hrBpm: bpm, flags: flags });
  }

  function onDistance() {
    let raw = null;
    try {
      raw = numberOrNull(distance.getCurrent());
    } catch (err) {
      raw = null;
    }
    store({
      kind: "DISTANCE",
      distanceRaw: raw,
      distanceUnit: "UNRESOLVED",
      distanceAttribution: "UNRESOLVED",
      flags: ["UNIT_UNRESOLVED"],
    });
  }

  function start() {
    if (running) {
      return { ok: true, already: true, sessionId: sessionId };
    }
    let enabled = true;
    try {
      if (geo.getEnabled) {
        enabled = geo.getEnabled() !== false;
      }
    } catch (err) {
      enabled = false;
    }
    sessionId = journal.nextSessionId();
    if (!enabled) {
      store({ kind: "LIFECYCLE", name: "PERMISSION_DENIED", flags: ["PERMISSION_DENIED"] });
      sessionId = "";
      return { ok: false, reason: "PERMISSION_DENIED" };
    }
    store({ kind: "LIFECYCLE", name: "START", flags: [] });
    gnssCb = onGnss;
    hrCb = onHr;
    try {
      geo.start();
      geo.onChange(gnssCb);
    } catch (err) {
      lastError = "GNSS_START_FAILED";
      store({ kind: "LIFECYCLE", name: "GNSS_START_FAILED", flags: ["GNSS_UNAVAILABLE"] });
    }
    if (geo.onGnssChange) {
      gnssInfoCb = (info) => {
        const body = info || {};
        lastSatellites = numberOrNull(body.nb_used_satellite);
        lastSignal = numberOrNull(body.top4_cn_val);
      };
      try {
        geo.onGnssChange(gnssInfoCb);
      } catch (err) {
        gnssInfoCb = null;
      }
    }
    try {
      hr.onCurrentChange(hrCb);
    } catch (err) {
      store({ kind: "HR", hrBpm: null, flags: ["HR_UNAVAILABLE"] });
      hrCb = null;
    }
    if (distance && distance.onChange) {
      distCb = onDistance;
      try {
        distance.onChange(distCb);
      } catch (err) {
        distCb = null;
        store({ kind: "DISTANCE", distanceRaw: null, distanceUnit: "UNRESOLVED", distanceAttribution: "UNRESOLVED", flags: ["DISTANCE_UNAVAILABLE"] });
      }
    } else {
      store({ kind: "DISTANCE", distanceRaw: null, distanceUnit: "UNRESOLVED", distanceAttribution: "UNRESOLVED", flags: ["DISTANCE_UNAVAILABLE"] });
    }
    if (sdk.display && sdk.display.onStatusChange) {
      displayCb = (status) => {
        const raw = status == null ? "" : String(status);
        const off = raw === "0" || raw.toLowerCase() === "off";
        store({ kind: "LIFECYCLE", name: off ? "DISPLAY_OFF" : "DISPLAY_" + raw, flags: [] });
      };
      try {
        sdk.display.onStatusChange(displayCb);
      } catch (err) {
        displayCb = null;
      }
    }
    running = true;
    return { ok: true, sessionId: sessionId };
  }

  function stop() {
    if (gnssCb && geo.offChange) {
      try {
        geo.offChange(gnssCb);
      } catch (err) {
        lastError = "GNSS_STOP_FAILED";
      }
    }
    gnssCb = null;
    if (gnssInfoCb && geo.offGnssChange) {
      try {
        geo.offGnssChange(gnssInfoCb);
      } catch (err) {
        lastError = "GNSS_STOP_FAILED";
      }
    }
    gnssInfoCb = null;
    try {
      geo.stop();
    } catch (err) {
      lastError = "GNSS_STOP_FAILED";
    }
    if (hrCb && hr.offCurrentChange) {
      try {
        hr.offCurrentChange(hrCb);
      } catch (err) {
        lastError = "HR_STOP_FAILED";
      }
    }
    hrCb = null;
    if (distCb && distance && distance.offChange) {
      try {
        distance.offChange(distCb);
      } catch (err) {
        lastError = "DISTANCE_STOP_FAILED";
      }
    }
    distCb = null;
    if (displayCb && sdk.display && sdk.display.offStatusChange) {
      try {
        sdk.display.offStatusChange(displayCb);
      } catch (err) {
        lastError = "DISPLAY_STOP_FAILED";
      }
    }
    displayCb = null;
    if (running) {
      store({ kind: "LIFECYCLE", name: "STOP", flags: [] });
    }
    running = false;
  }

  function noteLifecycle(name) {
    store({ kind: "LIFECYCLE", name: name, flags: [] });
  }

  return {
    start: start,
    stop: stop,
    noteLifecycle: noteLifecycle,
    running: () => running,
    sessionId: () => sessionId,
    lastError: () => lastError,
    listeners: () => ({ gnss: gnssCb, hr: hrCb, distance: distCb }),
  };
}
