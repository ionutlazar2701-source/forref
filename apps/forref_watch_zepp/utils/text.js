import { getLanguage } from "@zos/settings";
import { state } from "./state";

const EN = {
  app: "FORREF",
  demo: "DEMO FIXTURE",
  tempDefault: "TEMPORARY DEMO DEFAULT",
  officiate: "OFFICIATE",
  train: "TRAIN",
  settings: "SETTINGS",
  back: "BACK",
  select: "SELECT MATCH",
  unverified: "NOT A VERIFIED PACKAGE",
  fixture: "RIVERSIDE · MAPLE",
  when: "TODAY 15:00",
  hub: "PRE-MATCH",
  clockStopped: "CLOCK STOPPED",
  coin: "COIN TOSS",
  warmup: "WARM-UP",
  incident: "PRE-GAME INCIDENT",
  prepare: "KICK-OFF PREP",
  tossQ: "WHO WON THE TOSS?",
  home: "HOME",
  away: "AWAY",
  choice: "WINNER CHOOSES",
  kick: "KICK OFF",
  attack: "ATTACK A GOAL",
  review: "REVIEW",
  notRecorded: "DEMO — NOT RECORDED",
  directionOpen: "GOAL DIRECTION UNRESOLVED",
  warmupBody: "OPTIONAL. MATCH CLOCK UNAFFECTED.",
  incidentBody: "OPEN. CLASSIFICATION NOT IMPLEMENTED.",
  readyTitle: "READY FOR KICK-OFF",
  readyBody: "KICK-OFF NOT PERFORMED",
  openLive: "OPEN LIVE FIXTURE",
  liveA: "A TEAM SPLIT",
  liveC: "C VERTICAL",
  display: "DISPLAY",
  clockReady: "1ST HALF · READY",
  period1: "1ST HALF",
  period2: "2ND HALF",
  running: "RUNNING",
  paused: "PAUSED",
  halfTime: "HALF-TIME",
  fullTimeState: "FULL TIME",
  kickOff: "KICK OFF",
  pause: "PAUSE",
  resume: "RESUME",
  endFirst: "END 1ST HALF",
  startSecond: "START 2ND HALF",
  fullTime: "FULL TIME",
  continueClock: "CONTINUE FROM LAST",
  matchControls: "MATCH CONTROLS",
  backToLive: "BACK TO LIVE",
  clockPaused: "CLOCK PAUSED",
  matchSuspended: "MATCH SUSPENDED",
  suspendGame: "SUSPEND GAME",
  resumeGame: "RESUME GAME",
  abandonGame: "ABANDON GAME",
  confirmAbandon: "CONFIRM ABANDON",
  abandoned: "ABANDONED",
  notFullTime: "NOT FULL TIME",
  scoreUnavailable: "SCORE UNAVAILABLE",
  homeScore: "HOME · NO SCORE",
  awayScore: "AWAY · NO SCORE",
  timeUnverified: "TIME UNVERIFIED",
  recoveryRequired: "RECOVERY REQUIRED",
  clockTrust: "PROTOTYPE · NOT CERTIFIED",
  lastKnown: "LAST KNOWN",
  notApplied: "NOT APPLIED",
  alreadyApplied: "ALREADY APPLIED",
  notCompleted: "NOT COMPLETED",
  choose: "CHOOSE EVENT",
  yellow: "YELLOW",
  red: "RED",
  goal: "GOAL",
  sub: "SUB",
  player: "PARTICIPANT",
  unknown: "UNKNOWN",
  p9: "PLAYER 9",
  p4: "PLAYER 4",
  recordingOff: "DEMO — RECORDING NOT AVAILABLE",
  displayTitle: "LIVE MATCH DISPLAY",
  notProduct: "NOT A PRODUCT DEFAULT",
  memoryOnly: "IN MEMORY ONLY",
  cautions: "CAUTIONS RECALL",
  cautionsBody: "OPEN DESIGN GATE G1. NO COMPLETE LEDGER.",
  neutral: "NEUTRAL OPERATIONS",
  neutralBody: "OPEN DESIGN GATE G2. NO TEAM ASSIGNED.",
  halftime: "HALFTIME",
  halftimeBody: "DEMO STATE. CLOCK NOT RUNNING.",
  recovery: "RECOVERY",
  recoveryBody: "TIME UNRESOLVED. NO FABRICATED CLOCK.",
  finish: "FINISH",
  finishBody: "LOCAL FINISH NOT AVAILABLE.",
  trainTitle: "TRAIN",
  trainBody: "SEPARATE FROM THE MATCH.",
  trainWarm: "TRAIN WARM-UP",
  trainWarmBody: "NOT THE MATCH WARM-UP.",
  trainLive: "TRAINING SESSION",
  trainLiveBody: "NOT MEASURED. TIMER NOT RUNNING.",
  trainDone: "TRAINING SUMMARY",
  trainDoneBody: "NOT SAVED. NOT SYNCED.",
  period: "PERIOD",
  localeOs: "TEST ONLY: OS",
  localeRo: "TEST ONLY: RO",
  localeEn: "TEST ONLY: EN",
};

const RO = {
  app: "FORREF",
  demo: "FIXTURĂ DEMO",
  tempDefault: "IMPLICIT TEMPORAR DEMO",
  officiate: "ARBITRAJ",
  train: "ANTRENAMENT",
  settings: "SETĂRI",
  back: "ÎNAPOI",
  select: "ALEGE MECIUL",
  unverified: "PACHET NEVERIFICAT",
  fixture: "RIVERSIDE · MAPLE",
  when: "AZI 15:00",
  hub: "ÎNAINTE DE MECI",
  clockStopped: "CEAS OPRIT",
  coin: "ARUNCAREA MONEZII",
  warmup: "ÎNCĂLZIRE",
  incident: "INCIDENT ÎNAINTE DE JOC",
  prepare: "PREGĂTIRE FLUIER",
  tossQ: "CINE A CÂȘTIGAT?",
  home: "GAZDĂ",
  away: "OASPETE",
  choice: "CÂȘTIGĂTORUL ALEGE",
  kick: "LOVITURĂ DE ÎNCEPUT",
  attack: "ATACĂ O POARTĂ",
  review: "VERIFICARE",
  notRecorded: "DEMO — NEÎNREGISTRAT",
  directionOpen: "DIRECȚIA PORȚII NEREZOLVATĂ",
  warmupBody: "OPȚIONAL. CEASUL MECIULUI NU PORNEȘTE.",
  incidentBody: "DESCHIS. CLASIFICAREA NU E IMPLEMENTATĂ.",
  readyTitle: "GATA DE FLUIER",
  readyBody: "FLUERUL NU A FOST DAT",
  openLive: "DESCHIDE FIXTURA LIVE",
  liveA: "A ECHIPE",
  liveC: "C VERTICAL",
  display: "AFIȘAJ",
  clockReady: "REPRIZA 1 · GATA",
  period1: "REPRIZA 1",
  period2: "REPRIZA 2",
  running: "ÎN JOC",
  paused: "OPRIT",
  halfTime: "PAUZA DE MECI",
  fullTimeState: "SFÂRȘIT DE JOC",
  kickOff: "FLUER DE ÎNCEPUT",
  pause: "PAUZĂ",
  resume: "REIA",
  endFirst: "SFÂRȘIT REPRIZA 1",
  startSecond: "ÎNCEPE REPRIZA 2",
  fullTime: "TIMPUL REGULAMENTAR",
  continueClock: "CONTINUĂ DE LA ULTIMUL",
  matchControls: "COMENZI MECI",
  backToLive: "ÎNAPOI LA MECI",
  clockPaused: "CEAS OPRIT",
  matchSuspended: "MECI SUSPENDAT",
  suspendGame: "SUSPENDĂ MECIUL",
  resumeGame: "REIA MECIUL",
  abandonGame: "ABANDONEAZĂ",
  confirmAbandon: "CONFIRMĂ ABANDON",
  abandoned: "ABANDONAT",
  notFullTime: "NU E SFÂRȘIT",
  scoreUnavailable: "SCOR INDISPONIBIL",
  homeScore: "GAZDĂ · FĂRĂ SCOR",
  awayScore: "OASPETE · FĂRĂ SCOR",
  timeUnverified: "TIMP NEVERIFICAT",
  recoveryRequired: "RECUPERARE NECESARĂ",
  clockTrust: "PROTOTIP · NECERTIFICAT",
  lastKnown: "ULTIMUL CUNOSCUT",
  notApplied: "NEAPLICAT",
  alreadyApplied: "DEJA APLICAT",
  notCompleted: "NEFINALIZAT",
  choose: "ALEGE EVENIMENTUL",
  yellow: "GALBEN",
  red: "ROȘU",
  goal: "GOL",
  sub: "SCHIMBARE",
  player: "PARTICIPANT",
  unknown: "NECUNOSCUT",
  p9: "JUCĂTOR 9",
  p4: "JUCĂTOR 4",
  recordingOff: "DEMO — ÎNREGISTRAREA NU E DISPONIBILĂ",
  displayTitle: "AFIȘAJ LIVE",
  notProduct: "NU E IMPLICITUL DE PRODUS",
  memoryOnly: "DOAR ÎN MEMORIE",
  cautions: "CARTONAȘE",
  cautionsBody: "POARTĂ DESCHISĂ G1. FĂRĂ LISTĂ COMPLETĂ.",
  neutral: "OPERAȚII NEUTRE",
  neutralBody: "POARTĂ DESCHISĂ G2. FĂRĂ ECHIPĂ.",
  halftime: "PAUZĂ",
  halftimeBody: "STARE DEMO. CEASUL NU RULEAZĂ.",
  recovery: "RECUPERARE",
  recoveryBody: "TIMP NEREZOLVAT. FĂRĂ CEAS INVENTAT.",
  finish: "FINAL",
  finishBody: "FINALUL LOCAL NU E DISPONIBIL.",
  trainTitle: "ANTRENAMENT",
  trainBody: "SEPARAT DE MECI.",
  trainWarm: "ÎNCĂLZIRE ANTRENAMENT",
  trainWarmBody: "NU E ÎNCĂLZIREA MECIULUI.",
  trainLive: "SESIUNE",
  trainLiveBody: "NEMĂSURAT. CRONOMETRUL NU RULEAZĂ.",
  trainDone: "REZUMAT ANTRENAMENT",
  trainDoneBody: "NESALVAT. NESINCRONIZAT.",
  period: "PERIOADĂ",
  localeOs: "TEST ONLY: OS",
  localeRo: "TEST ONLY: RO",
  localeEn: "TEST ONLY: EN",
};

export function language() {
  try {
    return getLanguage();
  } catch (err) {
    return -1;
  }
}

export function localeChoice() {
  const code = language();
  const override = state().localeTest || "";
  if (override === "ro-RO") {
    return { lang: "ro-RO", reason: "TEST_ONLY", code: code };
  }
  if (override === "en-US") {
    return { lang: "en-US", reason: "TEST_ONLY", code: code };
  }
  if (code === 21) {
    return { lang: "ro-RO", reason: "os", code: code };
  }
  if (code === 2) {
    return { lang: "en-US", reason: "os", code: code };
  }
  return { lang: "en-US", reason: "fallback", code: code };
}

export function t(key) {
  const choice = localeChoice();
  const table = choice.lang === "ro-RO" ? RO : EN;
  return table[key] || EN[key] || key;
}

export function showTeam(token) {
  if (token === "HOME") return t("home");
  if (token === "AWAY") return t("away");
  return token || "";
}

export function showEvent(token) {
  if (token === "YELLOW") return t("yellow");
  if (token === "RED") return t("red");
  if (token === "GOAL") return t("goal");
  if (token === "SUB") return t("sub");
  return token || "";
}

export function showPlayer(token) {
  if (token === "PLAYER 9") return t("p9");
  if (token === "PLAYER 4") return t("p4");
  if (token === "UNKNOWN") return t("unknown");
  return token || "";
}

export function tables() {
  return { EN, RO };
}
