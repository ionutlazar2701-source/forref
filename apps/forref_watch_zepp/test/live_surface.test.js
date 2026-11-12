import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { layoutLive, controlsOk } from "../utils/geometry.js";

const live = readFileSync(new URL("../page/gt/live/index.page.js", import.meta.url), "utf8");
const controls = readFileSync(new URL("../page/gt/controls/index.page.js", import.meta.url), "utf8");
const text = readFileSync(new URL("../utils/text.js", import.meta.url), "utf8");
const ready = readFileSync(new URL("../page/gt/ready/index.page.js", import.meta.url), "utf8");

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
    "timeUnverified",
  ];
  for (const key of keys) {
    const hits = text.split(key + ":").length - 1;
    assert.equal(hits >= 2, true, key);
  }
});
