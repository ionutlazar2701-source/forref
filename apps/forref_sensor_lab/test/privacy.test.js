import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { tables } from "../utils/text.js";

function read(path) {
  return readFileSync(new URL(path, import.meta.url), "utf8");
}

test("the lab is a separate app and does not touch the production watch contract", () => {
  const app = JSON.parse(read("../app.json"));
  const production = JSON.parse(read("../../forref_watch_zepp/app.json"));
  const service = read("../app-service/hr_only.js");
  const host = read("../lib/host.js");
  const home = read("../page/gt/home/index.page.js");
  assert.equal(production.targets.gt.module.page.pages.length, 23);
  assert.equal(production.app.appId, 29566);
  assert.equal(app.app.appId, 30101);
  assert.notEqual(app.app.appId, production.app.appId);
  assert.equal(app.permissions.indexOf("device:os.geolocation") >= 0, true);
  assert.equal(app.permissions.indexOf("data:user.hd.heart_rate") >= 0, true);
  assert.equal(app.permissions.indexOf("data:user.hd.distance") >= 0, true);
  assert.equal(app.targets.gt.module.page.pages.length, 4);
  assert.equal(service.includes("Geolocation"), false);
  assert.equal(service.includes("HeartRate"), true);
  assert.equal(host.includes("@zos/sensor"), false);
  assert.equal(home.includes("Saved"), false);
  assert.equal(home.includes("capture_candidate"), false);
  assert.equal(home.includes("clock_device"), false);
  assert.equal(read("../../forref_watch_zepp/utils/clock_device.js").includes("forref_sens_001"), false);
  const keys = Object.keys(tables().EN);
  for (let i = 0; i < keys.length; i++) {
    assert.equal(typeof tables().RO[keys[i]], "string", keys[i]);
  }
});

test("console lines do not print coordinates or pulse values", () => {
  const files = [
    "../lib/host.js",
    "../app.js",
    "../app-service/hr_only.js",
    "../page/gt/home/index.page.js",
    "../page/gt/status/index.page.js",
    "../page/gt/track/index.page.js",
    "../page/gt/heat/index.page.js",
    "../utils/device_fs.js",
  ];
  for (let i = 0; i < files.length; i++) {
    const text = read(files[i]);
    const logs = text.split("console.log");
    for (let j = 1; j < logs.length; j++) {
      const body = logs[j].slice(0, logs[j].indexOf(");") + 2);
      assert.equal(/lat|lon|hrBpm|getLatitude|getLongitude|getCurrent/.test(body), false, files[i]);
    }
  }
});
