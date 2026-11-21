const EN = {
  title: "Duration probe",
  perm: "Permission",
  ask: "Request",
  call: "Call",
  code: "Code",
  raw: "Duration",
  state: "State",
  request: "REQUEST PERMISSION",
  read: "READ DURATION",
  notMatch: "NOT A MATCH RECORD",
};

const RO = {
  title: "Sondă durată",
  perm: "Permisiune",
  ask: "Cerere",
  call: "Apel",
  code: "Cod",
  raw: "Durată",
  state: "Stare",
  request: "CERE PERMISIUNEA",
  read: "CITEȘTE DURATA",
  notMatch: "NU E RECORD DE MECI",
};

export function localeChoice(code) {
  if (code === 21) {
    return "ro-RO";
  }
  return "en-US";
}

export function t(key, code) {
  const table = localeChoice(code) === "ro-RO" ? RO : EN;
  return table[key] || EN[key] || key;
}

export function tables() {
  return { EN: EN, RO: RO };
}

export function lines(state, code) {
  const ask = (state.requestImmediate == null ? "-" : String(state.requestImmediate)) + "/" + (state.requestList == null ? "-" : String(state.requestList));
  const call = state.accepted === true ? "1" : state.accepted === false ? "0" : "-";
  const shown = state.durationText || "-";
  const reason = state.reason && state.reason !== "DISPLAY_STRING_NOT_ELAPSED" && state.reason !== "IDLE" ? " " + state.reason : "";
  const referee = state.referee ? " " + state.referee : "";
  return [
    { name: "perm", text: t("perm", code) + " " + (state.permission == null ? "-" : String(state.permission)) + " " + state.permissionReason },
    { name: "ask", text: t("ask", code) + " " + ask },
    { name: "call", text: t("call", code) + " " + call },
    { name: "code", text: t("code", code) + " " + (state.code == null ? "-" : String(state.code)) },
    { name: "raw", text: t("raw", code) + " " + shown },
    { name: "state", text: t("state", code) + " " + state.status + reason + referee },
  ];
}
