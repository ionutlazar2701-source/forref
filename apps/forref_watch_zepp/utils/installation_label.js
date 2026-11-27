// Display-only split of the watch installation UUID. Identity creation stays in installation_id.js.
export const INSTALLATION_CHAR_EM = 0.62;
const LINE_CHARS = 18;

export function splitInstallationId(id) {
  const text = String(id || "");
  const lines = [];
  if (!text) return lines;
  for (let i = 0; i < text.length; i += LINE_CHARS) {
    lines.push(text.slice(i, i + LINE_CHARS));
  }
  return lines;
}

export function installationLineSize(slotWidth, slotHeight, line) {
  const count = Math.max(String(line || "").length, 1);
  const byWidth = Math.floor((slotWidth - 16) / count / INSTALLATION_CHAR_EM);
  const byHeight = slotHeight - 4;
  return Math.max(14, Math.min(32, byWidth, byHeight));
}

export function installationLineFits(slotWidth, line, size) {
  return String(line).length * INSTALLATION_CHAR_EM * size <= slotWidth - 16;
}

export function provisionIdentityRows(view, labels) {
  const id = view && view.installationId ? String(view.installationId) : "";
  const lines = splitInstallationId(id);
  const rows = [];
  if (!lines.length) {
    rows.push({ label: labels.missing });
  } else {
    for (let i = 0; i < lines.length; i += 1) {
      rows.push({ label: lines[i], fitText: true });
    }
  }
  rows.push({ label: labels.stage, warning: true });
  rows.push({ label: labels.match });
  rows.push({ label: labels.teams });
  rows.push({ label: labels.transport });
  rows.push({ label: labels.d1, warning: true });
  rows.push({ label: labels.provision, action: "start", name: "provision-start" });
  rows.push({ label: labels.back, action: "back", name: "provision-back" });
  return rows;
}
