import { loadInstallationId, readInstallationId } from "./installation_id.js";

// ZML 0.0.38 BasePage runs this during onInit, before the page build:
//   this.messaging = getApp()._options.globalData.messaging
//   this.messaging.onCall(...)
// The device app globalData is { demo: true } until a phone transport exists.
// That call throws and the UUID is never painted. Identity must not use BasePage.
export function messagingReady(globalData) {
  const messaging = globalData && globalData.messaging;
  if (!messaging || typeof messaging.onCall !== "function" || typeof messaging.request !== "function") {
    return false;
  }
  return true;
}

export function prepareInstallation(store) {
  let existing;
  try {
    existing = readInstallationId(store);
  } catch (err) {
    return { ok: false, id: "", reason: "exception", created: false };
  }
  if (existing.ok) {
    return { ok: true, id: existing.id, reason: "", created: false };
  }
  if (existing.reason !== "missing-installation") {
    return { ok: false, id: "", reason: existing.reason || "unreadable", created: false };
  }
  let created;
  try {
    created = loadInstallationId(store);
  } catch (err) {
    return { ok: false, id: "", reason: "exception", created: false };
  }
  if (!created.ok || !created.id) {
    return { ok: false, id: "", reason: created.reason || "unverified", created: false };
  }
  return { ok: true, id: created.id, reason: "", created: true };
}
