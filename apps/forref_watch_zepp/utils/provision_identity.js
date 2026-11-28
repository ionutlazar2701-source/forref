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

// A cached ZML object can still have request() after the page that opened
// the socket has been destroyed. connectStatus, the completed shake, and the
// side port are the health signals on @zeppos/zml 0.0.38. Objects without a
// transport are the test doubles and stay usable.
export function messagingAlive(messaging) {
  if (!messagingReady({ messaging: messaging })) return false;
  const transport = messaging.transport;
  if (!transport || typeof transport !== "object") return true;
  try {
    const ble = transport.ble;
    if (ble && typeof ble.connectStatus === "function" && !ble.connectStatus()) return false;
    if (typeof transport.shakeStatus === "number" && transport.shakeStatus !== 3) return false;
    if ("appSidePort" in transport && !transport.appSidePort) return false;
  } catch (err) {
    return false;
  }
  return true;
}

// PROVISION may send only while the LINK visit that opened the socket is still
// the owner. Page destruction sets the owner to 0. A full app restart has no
// messaging object yet.
export function messagingUsable(globalData) {
  if (!messagingReady(globalData) || !messagingAlive(globalData.messaging)) return false;
  const visit = globalData.linkSocketVisit;
  return typeof visit === "number" && Number.isInteger(visit) && visit >= 1;
}

// Zepp pages read getApp()._options.globalData. BaseApp also assigns the same
// object as this.globalData during onCreate. Accept either location.
export function readDeviceMessaging(app) {
  if (!app) return null;
  const options = app._options && app._options.globalData;
  if (messagingReady(options)) return options.messaging;
  if (messagingReady(app.globalData)) return app.globalData.messaging;
  return null;
}

export function prepareInstallation(store, options) {
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
  if (!options || options.allowCreate !== true) {
    return { ok: false, id: "", reason: "uninspected", created: false };
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
