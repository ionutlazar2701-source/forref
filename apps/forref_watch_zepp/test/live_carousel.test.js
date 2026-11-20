import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { layoutLive, layoutStack } from "../utils/geometry.js";
import { DISPLAY_CONTINUITY_MS } from "../utils/match_clock.js";
import {
  PAGE_CAUTIONS,
  PAGE_CONTROLS,
  PAGE_LIVE,
  applyPointerPage,
  arbitratePlatformGesture,
  arbitratePointer,
  backTarget,
  dotMarks,
  initialPage,
  transitionPage,
} from "../utils/live_carousel.js";
import { dotsClearOf, layoutDots, pageFits, rectsOverlap, stackLimit, teamSeparator } from "../utils/live_carousel_layout.js";

const round = { width: 480, height: 480, round: true };
const rect = { width: 390, height: 450, round: false };
const live = readFileSync(new URL("../page/gt/live/index.page.js", import.meta.url), "utf8");
const foreground = readFileSync(new URL("../utils/clock_foreground_bind.js", import.meta.url), "utf8");
const session = readFileSync(new URL("../utils/live_session.js", import.meta.url), "utf8");
const service = readFileSync(new URL("../app-service/clock_service.js", import.meta.url), "utf8");

const CODES = { left: 1, right: 2, up: 3, down: 4 };

test("the workspace opens on Live and a page change carries no intent", () => {
  assert.equal(initialPage(), PAGE_LIVE);
  assert.equal(DISPLAY_CONTINUITY_MS, 2500);
  const step = transitionPage(PAGE_LIVE, PAGE_CONTROLS);
  assert.equal(step.index, PAGE_CONTROLS);
  assert.equal(step.disarm, true);
  assert.deepEqual(step.intents, []);
  assert.deepEqual(transitionPage(PAGE_CONTROLS, PAGE_CONTROLS).intents, []);
  assert.equal(transitionPage(PAGE_CAUTIONS, 9).index, PAGE_CAUTIONS);
  assert.deepEqual(dotMarks(PAGE_LIVE).map((dot) => dot.active), [false, true, false]);
  assert.deepEqual(dotMarks(PAGE_CONTROLS).map((dot) => dot.active), [true, false, false]);
  assert.equal(backTarget(PAGE_CONTROLS).leave, false);
  assert.equal(backTarget(PAGE_CONTROLS).index, PAGE_LIVE);
  assert.deepEqual(backTarget(PAGE_LIVE), { leave: true, index: PAGE_LIVE, intents: [] });
});

test("a horizontal move that starts on a team button does not select either team", () => {
  const lay = layoutLive(rect, "A");
  const home = lay.home;
  const decision = arbitratePointer(
    { x: home.x + 20, y: home.y + 20 },
    { x: home.x + 140, y: home.y + 24 },
    { home: lay.home, away: lay.away, primary: lay.display, controls: lay.back }
  );
  assert.equal(decision.kind, "cancel");
  assert.equal(decision.target, "");
  assert.deepEqual(decision.intents, []);
  const stayed = applyPointerPage(PAGE_LIVE, decision);
  assert.equal(stayed.changed, false);
  assert.deepEqual(stayed.intents, []);
});

test("a deliberate empty-space swipe would move the page and still emit no intent", () => {
  const lay = layoutLive(rect, "A");
  const decision = arbitratePointer(
    { x: 180, y: 80 },
    { x: 40, y: 84 },
    { home: lay.home, away: lay.away, primary: lay.display, controls: lay.back }
  );
  assert.equal(decision.kind, "swipe");
  assert.equal(decision.pageDelta, 1);
  assert.deepEqual(decision.intents, []);
  const next = applyPointerPage(PAGE_LIVE, decision);
  assert.equal(next.index, PAGE_CAUTIONS);
  assert.deepEqual(next.intents, []);
  const tap = arbitratePointer(
    { x: lay.home.x + 12, y: lay.home.y + 12 },
    { x: lay.home.x + 16, y: lay.home.y + 14 },
    { home: lay.home, away: lay.away }
  );
  assert.equal(tap.kind, "tap");
  assert.equal(tap.target, "home");
});

test("platform gestures do not page forward and do not consume system back on Live", () => {
  for (const index of [PAGE_CONTROLS, PAGE_LIVE, PAGE_CAUTIONS]) {
    const left = arbitratePlatformGesture(CODES.left, CODES, index);
    assert.equal(left.gate, "BLOCKED");
    assert.equal(left.consume, false);
    assert.equal(left.pageDelta, 0);
    assert.equal(left.reason, "NO_TOUCH_OWNERSHIP");
    assert.deepEqual(left.intents, []);
  }
  const back = arbitratePlatformGesture(CODES.right, CODES, PAGE_LIVE);
  assert.equal(back.consume, false);
  assert.equal(back.reason, "SYSTEM_BACK");
  const recover = arbitratePlatformGesture(CODES.right, CODES, PAGE_CAUTIONS);
  assert.equal(recover.consume, true);
  assert.equal(recover.reason, "PAGE_BACK");
  assert.equal(recover.index, PAGE_LIVE);
  assert.deepEqual(recover.intents, []);
  assert.equal(arbitratePlatformGesture(CODES.up, CODES, PAGE_LIVE).reason, "IGNORED");
});

test("dots and the interior separator stay off the team and control hit rectangles", () => {
  for (const info of [rect, round]) {
    for (const mode of ["A", "C"]) {
      const lay = layoutLive(info, mode);
      assert.equal(dotsClearOf(info, [lay.home, lay.away, lay.display, lay.back]), true, mode + " " + info.width);
      const rule = teamSeparator(lay.home, lay.away);
      assert.ok(rule);
      assert.equal(rectsOverlap(rule, lay.home), false);
      assert.equal(rectsOverlap(rule, lay.away), false);
      const dots = layoutDots(info);
      assert.equal(dots.ok, true);
      const stacked = layoutStack(info, 6, stackLimit(info));
      assert.equal(pageFits(info, 6), true);
      assert.equal(pageFits(info, 4), true);
      assert.equal(dotsClearOf(info, stacked.rows), true);
    }
  }
});

test("the live page keeps the 1.0.6 clock path and does not treat a gesture as an intent", () => {
  assert.equal(live.includes("applyPointerPage"), false);
  assert.equal(live.includes("page/gt/controls/index.page"), true);
  assert.equal(live.includes("page/gt/cautions/index.page"), true);
  assert.equal(live.includes("bootLive"), true);
  assert.equal(live.includes("prepareFrame"), true);
  assert.equal(live.includes("performIntent"), true);
  assert.equal(live.includes('t("scoreUnavailable")'), false);
  assert.equal(live.includes("sampleFromScheduler"), false);
  const show = live.slice(live.indexOf("function showPage"), live.indexOf("function openControlsRoute"));
  assert.equal(show.includes("performIntent"), false);
  assert.equal(show.includes("KICK_OFF"), false);
  assert.equal(live.includes("initialPage()"), true);
  assert.equal(foreground.includes("createTimer"), true);
  assert.equal(foreground.includes("sampleFromScheduler"), true);
  assert.equal(session.includes("liveFrame"), true);
  assert.equal(service.includes("createSysTimer"), true);
  const paint = live.slice(live.indexOf("function paintAll"));
  assert.equal(paint.indexOf("prepareFrame()") < paint.indexOf("clear()"), true);
});
