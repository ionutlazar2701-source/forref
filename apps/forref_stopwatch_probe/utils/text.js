const EN = {
  title: "Stopwatch probe",
  read: "Read",
  control: "Control",
  binding: "Binding",
  check: "Check",
  open: "Open",
  state: "State",
  launch: "OPEN STOPWATCH",
  notMatch: "NOT A MATCH RECORD",
};

const RO = {
  title: "Sondă cronometru",
  read: "Citire",
  control: "Control",
  binding: "Legătură",
  check: "Verificare",
  open: "Deschidere",
  state: "Stare",
  launch: "DESCHIDE CRONOMETRUL",
  notMatch: "NU E RECORD DE MECI",
};

export function t(key, code) {
  const table = code === 21 ? RO : EN;
  return table[key] || EN[key] || key;
}

export function tables() {
  return { EN: EN, RO: RO };
}

export function lines(state, code) {
  return [
    { name: "read", text: t("read", code) + " " + state.read },
    { name: "control", text: t("control", code) + " " + state.control },
    { name: "binding", text: t("binding", code) + " " + state.binding },
    { name: "check", text: t("check", code) + " " + state.check },
    { name: "open", text: t("open", code) + " " + state.open },
    { name: "state", text: t("state", code) + " " + state.status },
  ];
}
