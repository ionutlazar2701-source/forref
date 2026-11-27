import test from "node:test";
import assert from "node:assert/strict";
import { messagingAttached, openDeviceApp } from "../utils/device_app.js";

function detail(err) {
  return err && err.message ? err.message : String(err);
}

function host(base) {
  const seen = [];
  const logs = [];
  const app = {
    globalData: null,
  };
  function AppHost(options) {
    seen.push(options);
    app.globalData = options.globalData;
    options.onCreate.call(options);
  }
  openDeviceApp(AppHost, base, {
    onCreate(target) {
      target.globalData.clockEpoch = "e1";
      logs.push("boot");
    },
    onDestroy() {
      logs.push("shutdown");
    },
    log(line) {
      logs.push(line);
    },
    detail,
  });
  return { app, logs, options: seen[0] };
}

test("BaseApp messaging is published before the clock boot", () => {
  const opened = host((options) => {
    return {
      globalData: options.globalData,
      onCreate() {
        this.globalData.messaging = {
          onCall() {
            return this;
          },
          request() {
            return Promise.resolve(null);
          },
        };
        options.onCreate.call(this);
      },
      onDestroy() {
        options.onDestroy.call(this);
      },
    };
  });
  assert.equal(messagingAttached(opened.app.globalData), true);
  assert.equal(opened.app.globalData.clockEpoch, "e1");
  assert.equal(opened.app.globalData.demo, true);
  assert.equal(opened.logs.includes("boot"), true);
  assert.equal(opened.logs.includes("FORREF_PROVISION messaging=ready"), true);
});

test("a messaging init failure still boots the clock", () => {
  const opened = host(() => {
    return {
      globalData: { demo: true },
      onCreate() {
        throw new Error("ble");
      },
      onDestroy() {},
    };
  });
  assert.equal(opened.app.globalData.clockEpoch, "e1");
  assert.equal(messagingAttached(opened.app.globalData), false);
  assert.equal(opened.logs.includes("boot"), true);
  assert.equal(opened.logs.some((line) => line.includes("reason=messaging-init")), true);
  assert.equal(opened.logs.includes("FORREF_PROVISION messaging=absent"), true);
});

test("messaging that is assigned before a connect failure stays readable", () => {
  const opened = host((options) => {
    return {
      globalData: options.globalData,
      onCreate() {
        this.globalData.messaging = {
          onCall() {
            return this;
          },
          request() {
            return Promise.resolve(null);
          },
        };
        throw new Error("connect");
      },
      onDestroy() {},
    };
  });
  assert.equal(messagingAttached(opened.app.globalData), true);
  assert.equal(opened.app.globalData.clockEpoch, "e1");
  assert.equal(opened.logs.filter((line) => line === "boot").length, 1);
  assert.equal(opened.logs.includes("FORREF_PROVISION messaging=ready"), true);
});
