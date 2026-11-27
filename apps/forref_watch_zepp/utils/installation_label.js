// Display-only split of the watch installation UUID. Identity creation stays in installation_id.js.
import { place } from "./geometry.js";

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

export function layoutInstallationCard(info) {
  const title = place(info, info.round ? 36 : 72, 32, info.round ? 300 : info.width - 24);
  const line = place(info, title.y + title.h + 6, 40, title.w);
  const line2 = place(info, line.y + line.h + 4, 40, title.w);
  const status = place(info, line2.y + line2.h + 8, 32, title.w);
  const action = place(info, status.y + status.h + 8, 48, title.w);
  const back = place(info, action.y + action.h + 8, 44, title.w);
  const slots = [title, line, line2, status, action, back];
  return { ok: slots.every((slot) => slot.ok), title: title, line: line, line2: line2, status: status, action: action, back: back };
}

export function fallbackInstallationCard(info) {
  const x = 12;
  const w = Math.max(120, (info.width || 390) - 24);
  const title = { x: x, y: info && info.round ? 28 : 72, w: w, h: 28, ok: true };
  const line = { x: x, y: title.y + title.h + 4, w: w, h: 36, ok: true };
  const line2 = { x: x, y: line.y + line.h + 2, w: w, h: 36, ok: true };
  const status = { x: x, y: line2.y + line2.h + 6, w: w, h: 28, ok: true };
  const action = { x: x, y: status.y + status.h + 6, w: w, h: 44, ok: true };
  const back = { x: x, y: action.y + action.h + 6, w: w, h: 40, ok: true };
  return { ok: true, fallback: true, title: title, line: line, line2: line2, status: status, action: action, back: back };
}

export function resolveInstallationCard(info) {
  const card = layoutInstallationCard(info);
  if (card.ok) return card;
  return fallbackInstallationCard(info);
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
