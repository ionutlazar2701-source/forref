import test from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));

function importSpecifiers(source) {
  return [...source.matchAll(/from\s+"([^"]+)"/g)].map((match) => match[1]);
}

function walkFile(absolute, seen, files) {
  if (seen.has(absolute)) return;
  seen.add(absolute);
  files.push(absolute);
  const source = readFileSync(absolute, "utf8");
  for (const spec of importSpecifiers(source)) {
    if (!spec.startsWith(".")) continue;
    const next = resolve(dirname(absolute), spec);
    walkFile(next.endsWith(".js") ? next : next + ".js", seen, files);
  }
}

function listJs(dir, acc) {
  for (const name of readdirSync(dir)) {
    const absolute = join(dir, name);
    if (statSync(absolute).isDirectory()) listJs(absolute, acc);
    else if (name.endsWith(".js")) acc.push(absolute);
  }
  return acc;
}

test("the watch device bundle does not load ZML and registers App directly", () => {
  const app = readFileSync(join(root, "app.js"), "utf8");
  assert.equal(app.includes("App({"), true);
  assert.equal(app.includes("openDeviceApp"), false);
  assert.equal(app.includes("startForegroundClock"), true);
  assert.equal(app.includes("setWakeUpRelaunch"), true);
  const entries = [join(root, "app.js")];
  listJs(join(root, "page"), entries);
  listJs(join(root, "app-service"), entries);
  const seen = new Set();
  const files = [];
  for (const entry of entries) walkFile(entry, seen, files);
  const link = join(root, "page/gt/link/index.page.js");
  const provision = join(root, "page/gt/provision/index.page.js");
  const specs = files
    .filter((file) => file !== link && file !== provision)
    .flatMap((file) => importSpecifiers(readFileSync(file, "utf8")));
  const offenders = specs.filter((spec) => spec.includes("@zeppos/zml") || spec.includes("device_messaging") || spec.includes("device_app"));
  assert.deepEqual(offenders, []);
  for (const source of [readFileSync(link, "utf8"), readFileSync(provision, "utf8")]) {
    assert.equal(source.includes('from "@zeppos/zml/3.0/module/messaging/plugin/app"'), true);
    assert.equal(source.includes("base-app"), false);
  }
  const bootFiles = files.filter((file) => file.endsWith("/app.js") || file.includes("/app-service/") || file.endsWith("/home/index.page.js"));
  const bootText = bootFiles.map((file) => readFileSync(file, "utf8")).join("\n");
  assert.equal(bootText.includes("@zeppos/zml"), false);
  const side = readFileSync(join(root, "app-side/index.js"), "utf8");
  assert.equal(side.includes("@zeppos/zml/base-side"), true);
});
