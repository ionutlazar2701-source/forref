import { messagingAlive, messagingReady } from "./provision_identity.js";

// Publishes one ZML messaging object onto the running app. The plugin is
// injected by the LINK page so app boot does not load @zeppos/zml.
// The same LINK visit reuses a healthy socket. A later visit, or a socket
// whose shake or BLE status has failed, closes that object once and opens
// one replacement. A close that throws does not open a second socket.

function dataBags(app) {
  const bags = [];
  if (app && app.globalData && typeof app.globalData === "object") bags.push(app.globalData);
  const options = app && app._options && app._options.globalData;
  if (options && typeof options === "object" && bags.indexOf(options) < 0) bags.push(options);
  return bags;
}

function currentMessaging(bags) {
  for (let i = 0; i < bags.length; i += 1) {
    if (messagingReady(bags[i])) return bags[i].messaging;
  }
  return null;
}

export function messagingState(messaging) {
  const transport = messaging && messaging.transport;
  if (!transport || typeof transport !== "object") return { connect: "na", shake: "na", side: "na" };
  let connect = "na";
  try {
    const ble = transport.ble;
    if (ble && typeof ble.connectStatus === "function") connect = ble.connectStatus() ? "1" : "0";
  } catch (err) {
    connect = "0";
  }
  const shake = typeof transport.shakeStatus === "number" ? String(transport.shakeStatus) : "na";
  const side = "appSidePort" in transport ? (transport.appSidePort ? "1" : "0") : "na";
  return { connect: connect, shake: shake, side: side };
}

function logLink(action, messaging, reason) {
  const state = messagingState(messaging);
  const suffix = reason ? " reason=" + reason : "";
  try {
    console.log("FORREF_LINK tx=" + action + " connect=" + state.connect + " shake=" + state.shake + " side=" + state.side + suffix);
  } catch (err) {
    // logging must not decide the socket
  }
}

function rejectHandlers(messaging) {
  const handlers = messaging && messaging.transport && messaging.transport.handlers;
  if (!handlers || typeof handlers.forEach !== "function") return 0;
  let count = 0;
  handlers.forEach((entry) => {
    count += 1;
    const task = entry && entry.task;
    if (task && typeof task.reject === "function") {
      try {
        task.reject(new Error("released"));
      } catch (err) {
        // the request page already left
      }
    }
  });
  return count;
}

export function releaseDeviceMessaging(app, reason) {
  const bags = dataBags(app);
  const messaging = currentMessaging(bags);
  if (!messaging) return { ok: true, empty: true, handlers: 0 };
  const handlers = rejectHandlers(messaging);
  try {
    if (typeof messaging.disConnect === "function") messaging.disConnect();
  } catch (err) {
    logLink("recover", messaging, "close");
    return { ok: false, empty: false, handlers: handlers };
  }
  for (let i = 0; i < bags.length; i += 1) {
    if (bags[i].messaging === messaging) delete bags[i].messaging;
  }
  logLink("release", null, reason || "close");
  return { ok: true, empty: false, handlers: handlers };
}

export function nextLinkVisit(app) {
  const bags = dataBags(app);
  if (!bags.length) return 0;
  const current = bags[0].linkVisit;
  const visit = typeof current === "number" && Number.isInteger(current) && current >= 1 ? current + 1 : 1;
  for (let i = 0; i < bags.length; i += 1) bags[i].linkVisit = visit;
  return visit;
}

export function retireLinkVisit(app, visit) {
  const bags = dataBags(app);
  let retired = false;
  for (let i = 0; i < bags.length; i += 1) {
    if (bags[i].linkSocketVisit === visit) {
      bags[i].linkSocketVisit = 0;
      retired = true;
    }
  }
  return retired;
}

function publish(app, messaging, visit) {
  const bags = dataBags(app);
  for (let i = 0; i < bags.length; i += 1) {
    bags[i].messaging = messaging;
    if (visit != null) bags[i].linkSocketVisit = visit;
  }
}

export function attachDeviceMessaging(app, plugin, visit) {
  if (!app || typeof plugin !== "function") return null;
  const bags = dataBags(app);
  if (!bags.length) return null;
  const globalData = bags[0];
  const current = currentMessaging(bags);
  const alive = !current || messagingAlive(current);
  const ownerOk = visit == null || (globalData.linkSocketVisit === visit && visit !== 0);
  if (current && alive && ownerOk) {
    logLink("reuse", current, "");
    return current;
  }
  if (current) {
    const released = releaseDeviceMessaging(app, alive ? "visit" : "stale");
    if (!released.ok) return null;
  }
  let mixin;
  try {
    mixin = plugin(app);
  } catch (err) {
    logLink("connect", null, "plugin");
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
  const messaging = currentMessaging(dataBags(app));
  if (!messaging) return null;
  publish(app, messaging, visit);
  logLink("connect", messaging, "");
  return messaging;
}
