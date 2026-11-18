const EN = {
  title: "SENS V2",
  preparing: "PREPARING",
  recording: "RECORDING",
  hrMeasuring: "HR MEASURING",
  hrLive: "HR LIVE",
  hrLast: "HR LAST KNOWN",
  hrUnavailable: "HR UNAVAILABLE",
  hrStale: "HR STALE",
  hrPermission: "HR NO PERMISSION",
  gpsSearching: "GPS SEARCHING",
  gpsReady: "GPS READY",
  gpsWeak: "GPS WEAK",
  gpsLost: "GPS LOST",
  gpsRecovered: "GPS RECOVERED",
  gpsPermission: "GPS NO PERMISSION",
  gpsUnsupported: "GPS UNSUPPORTED",
  gpsStopped: "GPS STOPPED",
  gpsError: "GPS ERROR",
  enableHr: "ENABLE HR",
  startSession: "START SESSION",
  hrOnly: "HR ONLY",
  stop: "STOP",
  diagnostics: "DIAGNOSTICS",
  distanceUnavailable: "DISTANCE UNAVAILABLE",
  noGps: "NO GPS",
  experimental: "EXPERIMENTAL",
  uncertified: "UNCERTIFIED",
  gaps: "GAPS",
  battery: "BATTERY",
  batteryUnavailable: "BATTERY UNAVAILABLE",
  notMatch: "NOT A MATCH RECORD",
  back: "BACK",
  storageFull: "STORAGE FULL",
  savedNever: "NOT SAVED",
  noSession: "NO SESSION",
  perfUnavailable: "PERF UNAVAILABLE",
  memShort: "MEM",
  gpsCb: "GPS CB",
  hrCb: "HR CB",
  queueShort: "Q",
  dropShort: "DROP",
  flushShort: "FLUSH",
  failShort: "FAIL",
};

const RO = {
  title: "SENS V2",
  preparing: "PREGĂTIRE",
  recording: "ÎNREGISTRARE",
  hrMeasuring: "PULS ÎN MĂSURARE",
  hrLive: "PULS LIVE",
  hrLast: "PULS ULTIMUL CUNOSCUT",
  hrUnavailable: "PULS INDISPONIBIL",
  hrStale: "PULS VECHI",
  hrPermission: "PULS FĂRĂ PERMISIUNE",
  gpsSearching: "GPS CĂUTARE",
  gpsReady: "GPS GATA",
  gpsWeak: "GPS SLAB",
  gpsLost: "GPS PIERDUT",
  gpsRecovered: "GPS RECUPERAT",
  gpsPermission: "GPS FĂRĂ PERMISIUNE",
  gpsUnsupported: "GPS NESUPORTAT",
  gpsStopped: "GPS OPRIT",
  gpsError: "GPS EROARE",
  enableHr: "ACTIVEAZĂ PULS",
  startSession: "START SESIUNE",
  hrOnly: "DOAR PULS",
  stop: "STOP",
  diagnostics: "DIAGNOSTIC",
  distanceUnavailable: "DISTANȚĂ INDISPONIBILĂ",
  noGps: "FĂRĂ GPS",
  experimental: "EXPERIMENTAL",
  uncertified: "NECERTIFICAT",
  gaps: "GOLURI",
  battery: "BATERIE",
  batteryUnavailable: "BATERIE INDISPONIBILĂ",
  notMatch: "NU E RECORD DE MECI",
  back: "ÎNAPOI",
  storageFull: "STOCARE PLINĂ",
  savedNever: "NESALVAT",
  noSession: "FĂRĂ SESIUNE",
  perfUnavailable: "PERFORMANȚĂ INDISPONIBILĂ",
  memShort: "MEM",
  gpsCb: "GPS CB",
  hrCb: "HR CB",
  queueShort: "COADĂ",
  dropShort: "PIERDUTE",
  flushShort: "SCRIERE",
  failShort: "EȘEC",
};

export function localeChoice(code) {
  if (code === 21) {
    return { lang: "ro-RO", reason: "os", code: code };
  }
  if (code === 2) {
    return { lang: "en-US", reason: "os", code: code };
  }
  return { lang: "en-US", reason: "fallback", code: code == null ? -1 : code };
}

export function t(key, code) {
  const choice = localeChoice(code);
  const table = choice.lang === "ro-RO" ? RO : EN;
  return table[key] || EN[key] || key;
}

export function tables() {
  return { EN: EN, RO: RO };
}

export function gpsLabel(state, code) {
  const map = {
    SEARCHING: "gpsSearching",
    READY: "gpsReady",
    WEAK_OR_STALE: "gpsWeak",
    LOST: "gpsLost",
    RECOVERED: "gpsRecovered",
    PERMISSION_REQUIRED: "gpsPermission",
    UNSUPPORTED: "gpsUnsupported",
    STOPPED: "gpsStopped",
    ERROR: "gpsError",
  };
  return t(map[state] || "gpsStopped", code);
}

export function hrLabel(view, code) {
  if (view.hrState === "LIVE" && view.hrLive) {
    return t("hrLive", code) + " " + view.hrBpm;
  }
  if (view.hrState === "STALE" && view.hrLastKnown) {
    return t("hrLast", code);
  }
  if (view.hrState === "MEASURING" || view.hrState === "INITIALIZING") {
    return t("hrMeasuring", code);
  }
  if (view.hrState === "PERMISSION_REQUIRED") {
    return t("hrPermission", code);
  }
  if (view.hrState === "UNAVAILABLE") {
    return t("hrUnavailable", code);
  }
  return t("hrUnavailable", code);
}
