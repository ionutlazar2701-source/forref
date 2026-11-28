import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { openDeviceApp } from "../utils/device_app.js";

const root = fileURLToPath(new URL("..", import.meta.url));

function detail(err) {
  return err && err.message ? err.message : String(err);
}

function host(hooks) {
  const seen = [];
  const logs = [];
  const app = { globalData: null };
  function AppHost(options) {
    seen.push(options);
    app.globalData = options.globalData;
    options.onCreate.call(options);
  }
  const options = openDeviceApp(AppHost, {
    onCreate(target) {
      if (hooks && hooks.onCreate) hooks.onCreate(target);
      else target.globalData.clockEpoch = "e1";
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
  return { app, logs, options: seen[0] || options };
}

function importSpecifiers(source) {
  return [...source.matchAll(/from\s+"([^"]+)"/g)].map((match) => match[1]);
}

function localImports(source) {
  return importSpecifiers(source).filter((spec) => spec.startsWith("."));
}

function walkAppImports(start) {
  const seen = new Set();
  const files = [];
  function visit(absolute) {
    if (seen.has(absolute)) return;
    seen.add(absolute);
    files.push(absolute);
    const source = readFileSync(absolute, "utf8");
    for (const spec of localImports(source)) {
      const next = resolve(dirname(absolute), spec);
      visit(next.endsWith(".js") ? next : next + ".js");
    }
  }
  visit(resolve(root, start));
  return files;
}

test("device boot paints the clock without calling BaseApp", () => {
  let baseCalls = 0;
  function BaseApp() {
    baseCalls += 1;
    throw new Error("Cannot read properties of undefined (reading '__scopedGlobals__')");
  }
  const opened = host();
  assert.equal(baseCalls, 0);
  assert.equal(typeof BaseApp, "function");
  assert.equal(opened.app.globalData.demo, true);
  assert.equal(opened.app.globalData.clockEpoch, "e1");
  assert.equal(opened.app.globalData.messaging, undefined);
  assert.equal(opened.logs.includes("boot"), true);
  opened.options.onDestroy.call(opened.options);
  assert.equal(opened.logs.includes("shutdown"), true);
});

test("a boot exception still returns from App registration", () => {
  const opened = host({
    onCreate() {
      throw new Error("clock");
    },
  });
  assert.equal(opened.logs.some((line) => line.includes("reason=boot")), true);
  assert.equal(opened.app.globalData.demo, true);
});

test("the app entry and its imports do not load ZML", () => {
  const app = readFileSync(join(root, "app.js"), "utf8");
  const files = walkAppImports("app.js");
  assert.equal(files.some((file) => file.endsWith("app.js")), true);
  assert.equal(files.some((file) => file.endsWith("device_app.js")), true);
  assert.equal(files.some((file) => file.endsWith("device_messaging.js")), false);
  const specs = files.flatMap((file) => importSpecifiers(readFileSync(file, "utf8")));
  assert.equal(app.includes("openDeviceApp"), true);
  assert.equal(app.includes("startForegroundClock"), true);
  assert.equal(app.includes("setWakeUpRelaunch"), true);
  assert.equal(specs.some((spec) => spec.includes("@zeppos/zml")), false);
  assert.equal(specs.some((spec) => spec.includes("base-app")), false);
  assert.equal(specs.some((spec) => spec.includes("device_messaging")), false);
});

test("BaseApp throws before App() when scoped globals are absent", () => {
  const dir = mkdtempSync(join(tmpdir(), "forref-baseapp-"));
  const script = join(dir, "probe.mjs");
  const zml = join(root, "node_modules/@zeppos/zml/dist/zml-app.js");
  writeFileSync(
    script,
    [
      "globalThis.__$$R$$__ = (name) => {",
      "  if (name === '@zos/utils') return { EventBus: class { on(){return this} emit(){} off(){} }, log: { getLogger(){ return { info(){}, error(){}, warn(){}, log(){}, debug(){} }; } }, px(n){ return n; } };",
      "  if (name === '@zos/timer') return { setTimeout(){ return 1; }, clearTimeout(){} };",
      "  if (name === '@zos/ble') return { addListener(){}, createConnect(){}, connectStatus(){ return false; }, send(){ return true; }, disConnect(){} };",
      "  if (name === '@zos/ble/TransferFile') return class TransferFile { constructor(){ this.inbox = { on(){}, off(){}, emit(){}, getNextFile(){ return null; } }; this.outbox = { enqueueFile(){} }; } };",
      "  if (name === '@zos/app') return { getPackageInfo(){ return { appId: 29566 }; }, onMessage(){}, postMessage(){}, offMessage(){} };",
      "  return {};",
      "};",
      "globalThis.Buffer = Buffer;",
      "globalThis.__$$app$$__ = {};",
      "const { BaseApp } = await import(" + JSON.stringify(zml) + ");",
      "let registered = false;",
      "try {",
      "  BaseApp({ globalData: { demo: true }, onCreate() { registered = true; }, onDestroy() {} });",
      "  registered = true;",
      "} catch (err) {",
      "  console.log('THROW ' + err.message);",
      "}",
      "console.log('REGISTERED ' + registered);",
    ].join("\n"),
  );
  const result = spawnSync(process.execPath, [script], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.includes("__scopedGlobals__"), true);
  assert.equal(result.stdout.includes("REGISTERED false"), true);
  assert.equal(result.stdout.includes("REGISTERED true"), false);
});
