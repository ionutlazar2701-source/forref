import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { layoutProbe, rowFits } from "../lib/layout.js";
import { lines, tables } from "../utils/text.js";
import {
  UNKNOWN,
  admitDisplayedDigits,
  applyCall,
  classifyCall,
  classifyDataType,
  classifyGetProperty,
  initialScreen,
  stopwatchMatrix,
} from "../lib/native_stopwatch.js";

test("STOP_WATCH is a two-digit watchface display and not a read", () => {
  const row = classifyDataType("STOP_WATCH");
  assert.equal(row.surface, "WATCHFACE");
  assert.equal(row.mode, "DISPLAY");
  assert.equal(row.digits, 2);
  assert.equal(row.unit, "MINUTES_OR_SECONDS");
  assert.equal(row.readable, false);
  assert.equal(row.proven, false);
  assert.equal(classifyDataType("BATTERY").readable, false);
});

test("getProperty keys are widget configuration", () => {
  for (const key of ["x", "y", "w", "h", "text", "MORE", "TEXT"]) {
    const row = classifyGetProperty(key);
    assert.equal(row.kind, "WIDGET_CONFIGURATION", key);
    assert.equal(row.stopwatch, false);
    assert.equal(row.proven, false);
  }
  assert.equal(classifyGetProperty("STOP_WATCH").reason, "NOT_A_DOCUMENTED_READ");
  const shown = admitDisplayedDigits("34");
  assert.equal(shown.status, UNKNOWN);
  assert.equal(shown.proven, false);
  assert.equal(shown.reason, "DISPLAY_NOT_ELAPSED");
});

test("launch and check return no duration", () => {
  const launch = classifyCall("launchApp", undefined, false);
  assert.equal(launch.text, "void");
  assert.equal(launch.duration, null);
  assert.equal(launch.proven, false);
  assert.equal(classifyCall("checkSystemApp", undefined, false).reason, "RETURNS_VOID");
  assert.equal(classifyCall("launchApp", undefined, true).text, "throw");
  assert.equal(classifyCall("launchApp", 3934, false).reason, "NOT_A_DURATION");
  assert.equal(classifyCall("launchApp", 3934, false).duration, null);
  assert.equal(classifyCall("start", undefined, false).reason, "NO_PUBLIC_CONTROL");
  assert.equal(classifyCall("pause", undefined, false).reason, "NO_PUBLIC_CONTROL");
  assert.equal(classifyCall("resume", undefined, false).reason, "NO_PUBLIC_CONTROL");
  assert.equal(classifyCall("reset", undefined, false).reason, "NO_PUBLIC_CONTROL");
});

test("the screen never presents a duration as proven time", () => {
  let state = applyCall(initialScreen(), "check", classifyCall("checkSystemApp", undefined, false));
  state = applyCall(state, "open", classifyCall("launchApp", undefined, false));
  assert.equal(state.check, "void");
  assert.equal(state.open, "void");
  assert.equal(state.status, UNKNOWN);
  const rendered = lines(state, 21);
  assert.equal(rendered[0].text.indexOf("Citire") >= 0, true);
  assert.equal(rendered[5].text.indexOf("TIME_UNKNOWN") >= 0, true);
  assert.equal(rendered[5].text.indexOf("PROVEN_TIME") >= 0, false);
  const keys = Object.keys(tables().EN);
  for (let i = 0; i < keys.length; i += 1) {
    assert.equal(typeof tables().RO[keys[i]], "string", keys[i]);
  }
});

test("seven rows fit the Bip 6 rect and the probe does not count seconds", () => {
  const info = { width: 390, height: 450, round: false, screenShape: 0 };
  const laid = layoutProbe(info, 7);
  assert.ok(laid.rowH >= 28);
  for (let i = 0; i < laid.rows.length; i += 1) {
    assert.equal(rowFits(info, laid.rows[i]), true, "row " + i);
  }
  const page = readFileSync(new URL("../page/gt/home/index.page.js", import.meta.url), "utf8");
  const app = JSON.parse(readFileSync(new URL("../app.json", import.meta.url), "utf8"));
  const production = JSON.parse(readFileSync(new URL("../../forref_watch_zepp/app.json", import.meta.url), "utf8"));
  assert.equal(page.includes("createSysTimer"), false);
  assert.equal(page.includes("getSportData"), false);
  assert.equal(page.includes("hmUI.data_type"), false);
  assert.equal(page.includes("SYSTEM_APP_STOPWATCH"), true);
  assert.equal(page.includes("launchApp"), true);
  assert.equal(page.includes("checkSystemApp"), true);
  assert.equal(app.app.appId, 30103);
  assert.equal(app.permissions.indexOf("data:user.hd.workout"), -1);
  assert.equal(production.app.appId, 29566);
  assert.equal(production.targets.gt.module.page.pages.length, 23);
  const read = stopwatchMatrix().find((row) => row.capability === "read_elapsed_while_foreground");
  assert.equal(read.availability, "NO_PUBLIC_READ");
  assert.equal(read.state, "DOCUMENTED");
  const seen = stopwatchMatrix().find((row) => row.capability === "system_stopwatch_continues_behind_another_app");
  assert.equal(seen.state, "PROVEN");
});
