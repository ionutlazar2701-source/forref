const EN = {
  title: "SENS LAB",
  stopped: "STOPPED — NOT A MATCH",
  sampling: "SAMPLING — EXPERIMENTAL",
  start: "START",
  stop: "STOP",
  status: "STATUS",
  track: "TRACK",
  heat: "HEAT",
  deleteLocal: "DELETE LOCAL",
  deleteConfirm: "CONFIRM DELETE",
  permissionDenied: "PERMISSION DENIED",
  noFix: "NO FIX",
  fix: "FIX",
  hrUnavailable: "HR UNAVAILABLE",
  hrPresent: "HR PRESENT",
  distanceUnresolved: "DISTANCE UNIT UNRESOLVED",
  batteryUnavailable: "BATTERY UNAVAILABLE",
  noSamples: "NO SAMPLES",
  samplingStopped: "SAMPLING STOPPED",
  gap: "GAP",
  storageFull: "STORAGE FULL",
  heatUnavailable: "HEAT MAP UNAVAILABLE",
  noCalibration: "NO FIELD CALIBRATION",
  notMatch: "NOT A MATCH RECORD",
  experimental: "EXPERIMENTAL",
  serviceHrOnly: "HR SERVICE — NO GNSS",
  back: "BACK",
  deleted: "LOCAL DATA DELETED",
  corrupt: "JOURNAL UNVERIFIED",
  gnssUnavailable: "GNSS UNAVAILABLE",
  noReliableSpeed: "MAX SPEED UNAVAILABLE",
  session: "SESSION",
  hrSamples: "HR SAMPLES",
  hrTime: "HR TIME",
  hrTimeUnmeasured: "HR TIME UNMEASURED",
  sessionRequired: "SESSION REQUIRED",
};

const RO = {
  title: "LABORATOR SENZORI",
  stopped: "OPRIT — NU E MECI",
  sampling: "EȘANTIONARE — EXPERIMENTAL",
  start: "START",
  stop: "STOP",
  status: "STARE",
  track: "TRASEU",
  heat: "HARTĂ",
  deleteLocal: "ȘTERGE LOCAL",
  deleteConfirm: "CONFIRMĂ ȘTERGEREA",
  permissionDenied: "PERMISIUNE REFUZATĂ",
  noFix: "FĂRĂ FIX",
  fix: "FIX",
  hrUnavailable: "PULS INDISPONIBIL",
  hrPresent: "PULS PREZENT",
  distanceUnresolved: "DISTANȚĂ UNITATE NECLARĂ",
  batteryUnavailable: "BATERIE INDISPONIBILĂ",
  noSamples: "FĂRĂ EȘANTIOANE",
  samplingStopped: "EȘANTIONARE OPRITĂ",
  gap: "GOL",
  storageFull: "STOCARE PLINĂ",
  heatUnavailable: "HARTĂ INDISPONIBILĂ",
  noCalibration: "FĂRĂ CALIBRARE TEREN",
  notMatch: "NU E RECORD DE MECI",
  experimental: "EXPERIMENTAL",
  serviceHrOnly: "SERVICIU PULS — FĂRĂ GNSS",
  back: "ÎNAPOI",
  deleted: "DATE LOCALE ȘTERSE",
  corrupt: "JURNAL NEVERIFICAT",
  gnssUnavailable: "GNSS INDISPONIBIL",
  noReliableSpeed: "VITEZĂ MAX INDISPONIBILĂ",
  session: "SESIUNE",
  hrSamples: "EȘANTIOANE PULS",
  hrTime: "TIMP PULS",
  hrTimeUnmeasured: "TIMP PULS NEMĂSURAT",
  sessionRequired: "SESIUNE NECESARĂ",
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
