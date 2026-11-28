import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { attachDeviceMessaging, nextLinkVisit, releaseDeviceMessaging, retireLinkVisit } from "../utils/device_messaging.js";
import { messagingAlive, messagingUsable } from "../utils/provision_identity.js";

const helper = readFileSync(new URL("../utils/device_messaging.js", import.meta.url), "utf8");
const page = readFileSync(new URL("../page/gt/link/index.page.js", import.meta.url), "utf8");
const provision = readFileSync(new URL("../page/gt/provision/index.page.js", import.meta.url), "utf8");
const app = readFileSync(new URL("../app.js", import.meta.url), "utf8");

function liveTransport() {
  return {
    ble: { connectStatus: () => true },
    shakeStatus: 3,
    appSidePort: 20,
    handlers: new Map(),
  };
}

function pluginFactory() {
  let calls = 0;
  const sockets = [];
  function plugin() {
    calls += 1;
    const transport = liveTransport();
    const socket = {
      transport: transport,
      closed: 0,
      onCall() {
        return this;
      },
      onRequest() {
        return this;
      },
      onBleChanged() {
        return this;
      },
      request() {
        return Promise.resolve({ method: "PONG", seq: 1 });
      },
      connect() {
        return this;
      },
      disConnect() {
        this.closed += 1;
      },
    };
    sockets.push(socket);
    return {
      onCreate() {
        this.globalData.messaging = socket;
        socket.connect();
      },
    };
  }
  plugin.calls = () => calls;
  plugin.sockets = sockets;
  return plugin;
}

test("the same visit reuses one healthy socket", () => {
  const appState = { globalData: { demo: true, clockEpoch: "e1", linkSeq: 2 } };
  const plugin = pluginFactory();
  const first = attachDeviceMessaging(appState, plugin, 1);
  const second = attachDeviceMessaging(appState, plugin, 1);
  assert.equal(first, second);
  assert.equal(plugin.calls(), 1);
  assert.equal(first.closed, 0);
  assert.equal(appState.globalData.clockEpoch, "e1");
  assert.equal(appState.globalData.linkSeq, 2);
  assert.equal(appState.globalData.linkSocketVisit, 1);
  assert.equal(messagingAlive(first), true);
  assert.equal(messagingUsable(appState.globalData), true);
});

test("a new visit closes the cached socket once and opens one replacement", () => {
  const globalData = { demo: true, clockEpoch: "e1", linkSeq: 4 };
  const appState = { globalData: globalData, _options: { globalData: globalData } };
  const plugin = pluginFactory();
  const first = attachDeviceMessaging(appState, plugin, 1);
  const task = { rejected: 0, reject() { this.rejected += 1; } };
  first.transport.handlers.set(7, { task: task });
  retireLinkVisit(appState, 1);
  assert.equal(globalData.linkSocketVisit, 0);
  assert.equal(messagingUsable(globalData), false);
  const second = attachDeviceMessaging(appState, plugin, 2);
  assert.notEqual(first, second);
  assert.equal(first.closed, 1);
  assert.equal(second.closed, 0);
  assert.equal(plugin.calls(), 2);
  assert.equal(task.rejected, 1);
  assert.equal(globalData.clockEpoch, "e1");
  assert.equal(globalData.linkSeq, 4);
  assert.equal(globalData.demo, true);
  assert.equal(globalData.linkSocketVisit, 2);
  assert.equal(appState._options.globalData.messaging, second);
});

test("a dead BLE status is replaced once and a failed close does not open another socket", () => {
  const appState = { globalData: { demo: true, clockEpoch: "e1" } };
  const plugin = pluginFactory();
  const first = attachDeviceMessaging(appState, plugin, 1);
  first.transport.ble.connectStatus = () => false;
  assert.equal(messagingAlive(first), false);
  const second = attachDeviceMessaging(appState, plugin, 1);
  assert.notEqual(first, second);
  assert.equal(first.closed, 1);
  assert.equal(plugin.calls(), 2);
  second.disConnect = () => {
    throw new Error("ble");
  };
  second.transport.shakeStatus = 4;
  const third = attachDeviceMessaging(appState, plugin, 1);
  assert.equal(third, null);
  assert.equal(plugin.calls(), 2);
  assert.equal(appState.globalData.messaging, second);
  assert.equal(appState.globalData.clockEpoch, "e1");
});

test("retiring a visit does not drop a newer socket and release is idempotent", () => {
  const appState = { globalData: { demo: true, clockEpoch: "e1" } };
  assert.equal(nextLinkVisit(appState), 1);
  assert.equal(nextLinkVisit(appState), 2);
  const plugin = pluginFactory();
  const socket = attachDeviceMessaging(appState, plugin, 2);
  assert.equal(retireLinkVisit(appState, 1), false);
  assert.equal(appState.globalData.linkSocketVisit, 2);
  assert.equal(socket.closed, 0);
  const released = releaseDeviceMessaging(appState, "test");
  assert.equal(released.ok, true);
  assert.equal(socket.closed, 1);
  assert.equal(appState.globalData.messaging, undefined);
  assert.equal(appState.globalData.clockEpoch, "e1");
  const again = releaseDeviceMessaging(appState, "test");
  assert.equal(again.ok, true);
  assert.equal(again.empty, true);
  assert.equal(socket.closed, 1);
});

test("LINK destruction retires ownership and PROVISION will not send on that object", () => {
  const destroyAt = page.indexOf("onDestroy()");
  const pingAt = page.indexOf("ping() {");
  assert.equal(destroyAt > 0 && destroyAt < pingAt, true);
  assert.equal(page.slice(destroyAt, pingAt).includes("retireLinkVisit"), true);
  assert.equal(page.slice(destroyAt, pingAt).includes("attachDeviceMessaging"), false);
  assert.equal(page.slice(destroyAt, pingAt).includes("disConnect"), false);
  assert.equal(page.includes("page=destroy"), true);
  assert.equal(page.includes("tx=timeout"), true);
  assert.equal(page.includes("tx=drop"), true);
  assert.equal(helper.includes("disConnect"), true);
  assert.equal(helper.includes("clock_"), false);
  assert.equal(helper.includes("installation"), false);
  assert.equal(provision.includes("runSideDiagnostic"), true);
  assert.equal(provision.includes("runHandshake"), false);
  assert.equal(provision.includes("readProvisionEvidence"), true);
  assert.equal(provision.includes("onDestroy()"), true);
  assert.equal(app.includes("App({"), true);
  assert.equal(app.includes("@zeppos/zml"), false);
});
