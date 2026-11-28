import { messagingReady } from "./provision_identity.js";

// Publishes a ZML messaging object onto the running app. The plugin is
// injected by the provision page so app boot does not load @zeppos/zml.
// A second call does not open another BLE socket.

export function attachDeviceMessaging(app, plugin) {
  if (!app || typeof plugin !== "function") return null;
  const globalData = app.globalData || (app._options && app._options.globalData) || null;
  if (!globalData) return null;
  if (messagingReady(globalData)) return globalData.messaging;
  let mixin;
  try {
    mixin = plugin(app);
  } catch (err) {
    return null;
  }
  if (!mixin || typeof mixin.onCreate !== "function") return null;
  const host = {
    globalData: globalData,
    onCall: app.onCall,
    onRequest: app.onRequest,
    onBleChanged: app.onBleChanged,
  };
  try {
    mixin.onCreate.call(host);
  } catch (err) {
    // connect() can throw after messaging is already on globalData
  }
  const messaging = messagingReady(globalData) ? globalData.messaging : null;
  const options = app._options && app._options.globalData;
  if (messaging && options && options !== globalData) options.messaging = messaging;
  if (messaging && app.globalData && app.globalData !== globalData) app.globalData.messaging = messaging;
  return messaging;
}
