import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { attachDeviceMessaging } from "../utils/device_messaging.js";

const page = readFileSync(new URL("../page/gt/provision/index.page.js", import.meta.url), "utf8");

function messaging() {
  return {
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
      return Promise.resolve(null);
    },
    connect() {
      this.connected = true;
      return this;
    },
  };
}

function pluginFactory(behavior) {
  let calls = 0;
  function plugin() {
    calls += 1;
    if (behavior === "throw") throw new Error("ble");
    const transport = messaging();
    return {
      onCreate() {
        this.globalData.messaging = transport;
        if (behavior === "connect-throw") {
          this.globalData.messaging.connect();
          throw new Error("createConnect");
        }
        this.globalData.messaging.onCall().onRequest().onBleChanged().connect();
      },
    };
  }
  plugin.calls = () => calls;
  return plugin;
}

test("provision attaches messaging on the running app without a second socket", () => {
  const app = { globalData: { demo: true, clockEpoch: "e1" } };
  const plugin = pluginFactory("connect");
  const first = attachDeviceMessaging(app, plugin);
  const second = attachDeviceMessaging(app, plugin);
  assert.equal(first, second);
  assert.equal(first.connected, true);
  assert.equal(plugin.calls(), 1);
  assert.equal(app.globalData.clockEpoch, "e1");
  assert.equal(app.globalData.demo, true);
});

test("a plugin failure leaves the clock data and publishes nothing", () => {
  const app = { globalData: { demo: true, clockEpoch: "e1" } };
  assert.equal(attachDeviceMessaging(app, pluginFactory("throw")), null);
  assert.equal(app.globalData.messaging, undefined);
  assert.equal(app.globalData.clockEpoch, "e1");
});

test("messaging stays readable when connect throws after publish", () => {
  const app = {
    globalData: { demo: true, clockEpoch: "e1" },
    _options: { globalData: { demo: true } },
  };
  const attached = attachDeviceMessaging(app, pluginFactory("connect-throw"));
  assert.equal(attached.connected, true);
  assert.equal(app.globalData.messaging, attached);
  assert.equal(app._options.globalData.messaging, attached);
  assert.equal(app.globalData.clockEpoch, "e1");
});

test("the provision page attaches messaging only after the UUID is painted", () => {
  const buildStart = page.indexOf("build() {");
  const startFn = page.indexOf("start() {");
  assert.equal(buildStart > 0, true);
  assert.equal(startFn > buildStart, true);
  assert.equal(page.slice(buildStart, startFn).includes("attachDeviceMessaging"), false);
  assert.equal(page.slice(startFn).includes("readMessaging"), true);
  assert.equal(page.includes("attachDeviceMessaging(app, appPlugin)"), true);
  assert.equal(page.includes("@zeppos/zml/3.0/module/messaging/plugin/app"), true);
  assert.equal(page.includes("BaseApp"), false);
  assert.equal(page.includes("BasePage"), false);
  assert.equal(page.indexOf("prepareInstallation") < page.indexOf("runHandshake({"), true);
  assert.equal(page.includes("page=build"), true);
});
