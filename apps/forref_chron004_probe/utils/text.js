const EN = {
  title: "CHRON-004  RESEARCH",
  notMatch: "NOT A MATCH",
  start: "START",
  resume: "RESUME",
  secondHalf: "HALF 2",
  pause: "PAUSE",
  endHalf: "END H1",
  fullTime: "FULL",
  idle: "—",
};

const RO = {
  title: "CHRON-004  CERCETARE",
  notMatch: "NU E MECI",
  start: "START",
  resume: "CONTINUĂ",
  secondHalf: "REPRIZA 2",
  pause: "PAUZĂ",
  endHalf: "SFÂRȘIT H1",
  fullTime: "FINAL",
  idle: "—",
};

export function t(key, code) {
  const table = code === 21 ? RO : EN;
  return table[key] || EN[key] || key;
}
