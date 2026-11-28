import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { digitHoldKey, nextPaintDelay } from "../utils/display_cadence.js";
import { applyIntent, displayText, present } from "../utils/match_clock.js";
import { openUtcSession } from "../utils/clock_segment.js";

const EPOCH = "epoch-a";
const T0 = 1700000000000;

function kick(at) {
  const started = applyIntent(openUtcSession(EPOCH), "KICK_OFF", {
    utcMillis: at,
    epoch: EPOCH,
    intentId: "kick",
  });
  assert.equal(started.ok, true);
  return started.session;
}

function face(session, utc) {
  return displayText(present(session, utc));
}

const live = readFileSync(new URL("../page/gt/live/index.page.js", import.meta.url), "utf8");

test("the first paint waits only for the rest of the current UTC second", () => {
  assert.equal(nextPaintDelay(T0), 1000);
  assert.equal(nextPaintDelay(T0 + 1), 999);
  assert.equal(nextPaintDelay(T0 + 500), 500);
  assert.equal(nextPaintDelay(T0 + 999), 1);
  assert.equal(nextPaintDelay(T0 + 1000), 1000);
  assert.equal(nextPaintDelay(null), 1000);
  assert.equal(nextPaintDelay(Number.NaN), 1000);
});

test("twenty aligned paints show twenty consecutive seconds", () => {
  const session = kick(T0);
  let now = T0;
  const shown = [];
  for (let step = 0; step < 20; step += 1) {
    now += nextPaintDelay(now);
    shown.push(face(session, now));
  }
  assert.deepEqual(shown.slice(0, 5), ["00:01", "00:02", "00:03", "00:04", "00:05"]);
  assert.equal(shown[19], "00:20");
  assert.equal(session.openStartUtc, T0);
  assert.equal(session.firstHalfClosedMs, 0);
});

test("a late paint shows the real UTC delta and does not add one second per callback", () => {
  const session = kick(T0);
  assert.equal(face(session, T0 + 2000), "00:02");
  assert.equal(face(session, T0 + 2000), "00:02");
  assert.equal(face(session, T0 + 2500), "00:02");
  assert.equal(face(session, T0 + 3000), "00:03");
  assert.equal(session.openStartUtc, T0);
  assert.equal(session.firstHalfClosedMs, 0);
});

test("the same layout keeps its digit widgets when only the shown second changes", () => {
  const base = {
    mode: "A",
    unverified: false,
    added: false,
    telemetry: true,
    detail: true,
    phaseY: 40,
    timeY: 80,
  };
  const first = digitHoldKey(base);
  const second = digitHoldKey(base);
  assert.equal(first, second);
  assert.notEqual(digitHoldKey(Object.assign({}, base, { mode: "C" })), first);
  assert.notEqual(digitHoldKey(Object.assign({}, base, { unverified: true })), first);
  assert.notEqual(digitHoldKey(Object.assign({}, base, { detail: false })), first);
});

test("the live timer paints the projection on a 1000 ms period", () => {
  const timer = live.slice(live.indexOf("function ensureTimer"), live.indexOf("function stopClockTimer"));
  assert.equal(timer.includes("nextPaintDelay(deviceNow())"), true);
  assert.equal(timer.includes("createTimer(delay, 1000,"), true);
  assert.equal(timer.includes("createTimer(1000, 1000"), false);
  assert.equal(timer.includes("paintAll()"), true);
  assert.equal(timer.includes("firstHalfClosedMs"), false);
  assert.equal(timer.includes("+ 1000"), false);
  assert.equal(timer.includes("+ 2000"), false);
  const steady = live.slice(live.indexOf("if (!rebuild && digitHold"), live.indexOf("clearDigits()"));
  assert.equal(steady.includes("updateText("), true);
  assert.equal(steady.includes("deleteWidget"), false);
  assert.equal(live.includes("clearDigits()"), true);
});
