import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { layoutLive, controlsOk } from "../utils/geometry.js";

const live = readFileSync(new URL("../page/gt/live/index.page.js", import.meta.url), "utf8");
const controls = readFileSync(new URL("../page/gt/controls/index.page.js", import.meta.url), "utf8");
const text = readFileSync(new URL("../utils/text.js", import.meta.url), "utf8");
const ready = readFileSync(new URL("../page/gt/ready/index.page.js", import.meta.url), "utf8");
const stamp = readFileSync(new URL("../utils/build_stamp.js", import.meta.url), "utf8");
const session = readFileSync(new URL("../utils/live_session.js", import.meta.url), "utf8");
const appJson = JSON.parse(readFileSync(new URL("../app.json", import.meta.url), "utf8"));

const round = { width: 480, height: 480, round: true };
const rect = { width: 390, height: 450, round: false };

test("live A and C keep teams, the clock region, and both controls inside the safe area", () => {
  for (const mode of ["A", "C"]) {
    const roundLay = layoutLive(round, mode);
    const rectLay = layoutLive(rect, mode);
    assert.equal(controlsOk(roundLay), true, mode + " round");
    assert.equal(controlsOk(rectLay), true, mode + " rect");
    assert.ok(roundLay.home && roundLay.away && roundLay.display && roundLay.back);
    assert.ok(roundLay.timeY > roundLay.phaseY);
  }
});

test("the live surface is one session shared by A and C, with no fabricated time or score", () => {
  assert.equal(live.includes("layoutLive"), true);
  assert.equal(live.includes("layoutClock"), false);
  assert.equal(live.includes("67:12"), false);
  assert.equal(live.includes("1-0"), false);
  assert.equal(live.includes("1–0"), false);
  assert.equal(live.includes("bootLive"), true);
  assert.equal(live.includes("page/gt/controls/index.page"), true);
  assert.equal(live.includes("openTeam"), true);
  assert.equal(controls.includes("performIntent"), true);
  assert.equal(controls.includes("createTimer"), false);
  assert.equal(ready.includes("KICK_OFF"), false);
  assert.equal(ready.includes("page/gt/live/index.page"), true);
});

test("every new match-control label exists in English and Romanian", () => {
  const keys = [
    "matchControls",
    "backToLive",
    "clockPaused",
    "matchSuspended",
    "suspendGame",
    "resumeGame",
    "abandonGame",
    "confirmAbandon",
    "abandoned",
    "notFullTime",
    "scoreUnavailable",
    "homeScore",
    "awayScore",
    "timeUnverified",
  ];
  for (const key of keys) {
    const hits = text.split(key + ":").length - 1;
    assert.equal(hits >= 2, true, key);
  }
});

test("abandon confirmation is dropped on navigation, back, and page exit", () => {
  for (const source of [live, controls]) {
    assert.equal(source.includes('leave("navigate"'), true);
    assert.equal(source.includes('leave("back"'), true);
    assert.equal(source.includes('leave("exit"'), true);
    assert.equal(source.includes("arm.retain("), true);
    const exitAt = source.indexOf("onDestroy");
    assert.equal(exitAt > 0, true);
    assert.equal(source.indexOf('leave("exit")', exitAt) > exitAt, true);
  }
});

test("the first live paint admits the clock before it creates widgets", () => {
  const paint = live.slice(live.indexOf("function paintAll"));
  assert.equal(paint.indexOf("prepareFrame()") > -1, true);
  assert.equal(paint.indexOf("prepareFrame()") < paint.indexOf("clear()"), true);
  const digits = live.slice(live.indexOf("function paintDigits"), live.indexOf("function logView"));
  assert.equal(digits.includes("clearDigits()"), true);
  assert.equal(digits.includes("button("), false);
  assert.equal(session.indexOf("liveFrame") < session.indexOf("return frame.view"), true);
});

test("the boot line carries a revision and the route inventory is 23 including controls", () => {
  const pages = appJson.targets.gt.module.page.pages;
  assert.equal(pages.length, 23);
  assert.equal(pages.includes("page/gt/controls/index.page"), true);
  assert.equal(stamp.includes("BUILD_REV"), true);
  assert.equal(stamp.includes("rev="), true);
  assert.equal(live.includes("homeScore"), true);
  assert.equal(live.includes("awayScore"), true);
  assert.equal(live.includes('t("scoreUnavailable")'), false);
});
