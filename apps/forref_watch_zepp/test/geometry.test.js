import {
  SAFE_MARGIN,
  SQUARE_STATUS_BAR,
  inside,
  layoutStack,
  layoutLive,
  layoutEvent,
  layoutClock,
  layoutHome,
  controlsOk,
} from "../utils/geometry.js";

const round = { width: 480, height: 480, round: true };
const rect = { width: 390, height: 450, round: false };

function assert(cond, message) {
  if (!cond) {
    throw new Error(message);
  }
}

function assertLayout(info, bag, label) {
  const names = Object.keys(bag);
  for (let i = 0; i < names.length; i++) {
    const value = bag[names[i]];
    if (!value || typeof value.ok !== "boolean") {
      continue;
    }
    assert(value.ok, label + " " + names[i] + " " + JSON.stringify(value));
    assert(inside(info, value.x, value.y, value.w, value.h), label + " recheck " + names[i]);
  }
}

assert(SAFE_MARGIN === 12, "margin");
assert(SQUARE_STATUS_BAR === 64, "status bar");

assert(!inside(round, 96, 19, 288, 106), "old Live C HOME must fail the safe circle");
assert(!inside(round, 95, 394, 138, 57), "old Live C DISPLAY must fail the safe circle");
assert(!inside(round, 96, 400, 288, 52), "old event BACK must fail the safe circle");

for (let count = 1; count <= 7; count++) {
  const laid = layoutStack(round, count);
  assert(laid.rows.length === count, "round stack " + count);
  laid.rows.forEach((row, index) => {
    assert(row.ok, "round stack row " + count + ":" + index);
  });
  const square = layoutStack(rect, count);
  assert(square.rows.length === count, "rect stack " + count);
  square.rows.forEach((row, index) => {
    assert(row.y >= SQUARE_STATUS_BAR, "rect row under status bar " + index);
    assert(row.ok, "rect stack row " + count + ":" + index);
  });
}

["A", "C"].forEach((mode) => {
  const liveRound = layoutLive(round, mode);
  const liveRect = layoutLive(rect, mode);
  assert(controlsOk(liveRound), "round live " + mode);
  assert(controlsOk(liveRect), "rect live " + mode);
  assertLayout(round, liveRound, "round live " + mode);
  assertLayout(rect, liveRect, "rect live " + mode);
  assert(liveRect.home.y >= SQUARE_STATUS_BAR, "rect home below status bar");
});

const eventRound = layoutEvent(round);
const eventRect = layoutEvent(rect);
assert(controlsOk(eventRound), "round event");
assert(controlsOk(eventRect), "rect event");
assertLayout(round, eventRound, "round event");
assertLayout(rect, eventRect, "rect event");
assert(eventRect.yellow.y >= SQUARE_STATUS_BAR, "rect event below status bar");

for (let actions = 1; actions <= 2; actions++) {
  const clockRound = layoutClock(round, actions);
  const clockRect = layoutClock(rect, actions);
  assert(controlsOk(clockRound), "round clock " + actions);
  assert(controlsOk(clockRect), "rect clock " + actions);
  assertLayout(round, clockRound, "round clock " + actions);
  assertLayout(rect, clockRect, "rect clock " + actions);
  assert(clockRect.status.y >= SQUARE_STATUS_BAR, "rect clock below status bar");
  assert(clockRound.time.h >= 64, "round clock time stays glanceable");
}

const homeRound = layoutHome(round);
const homeRect = layoutHome(rect);
assert(homeRound.upper.w === homeRound.middle.w && homeRound.middle.w === homeRound.lower.w && homeRound.upper.w === 456, "round zones share the 456 frame width");
assert(homeRound.upper.h === 151 && homeRound.middle.h === 151 && homeRound.lower.h === 152, "round bands share the frame");
assert(homeRound.divider.y === 163 && homeRound.dividerLower.y === 315 && homeRound.divider.h === 1, "round dividers");
assert(homeRound.titleSize === 32 && homeRound.subtitleSize === 20, "round type matches the frame");
assert(homeRound.upperText.title.h === 40 && homeRound.upperText.subtitle.h === 28, "round line boxes");
assert(homeRect.upper.h === 124 && homeRect.middle.h === 124 && homeRect.lower.h === 124, "rect bands stay equal");
assert(homeRect.upper.y === SQUARE_STATUS_BAR, "rect home starts under the status bar");
assert(homeRect.lower.y + homeRect.lower.h === rect.height - SAFE_MARGIN, "rect home keeps the bottom inset");
assert(homeRect.upper.x === SAFE_MARGIN && homeRect.upper.w === 366, "rect side inset");
assert(homeRect.divider.y === 188 && homeRect.dividerLower.y === 313 && homeRect.divider.h === 1, "rect dividers");
assert(homeRect.titleSize === 26 && homeRect.subtitleSize === 16, "rect type keeps the 480 proportion");
assert(inside(rect, homeRect.upper.x, homeRect.upper.y, homeRect.upper.w, homeRect.upper.h), "rect upper zone");
assert(inside(rect, homeRect.middle.x, homeRect.middle.y, homeRect.middle.w, homeRect.middle.h), "rect middle zone");
assert(inside(rect, homeRect.lower.x, homeRect.lower.y, homeRect.lower.w, homeRect.lower.h), "rect lower zone");
assert(homeRect.middle.y === homeRect.divider.y + 1, "training starts under the first rule");
assert(homeRect.lower.y === homeRect.dividerLower.y + 1, "settings starts under the second rule");
assert(!inside(round, homeRound.upper.x, homeRound.upper.y, homeRound.upper.w, homeRound.upper.h), "round full-bleed zone is clipped by the glass");

console.log("FORREF_GEOMETRY_TEST pass margin=" + SAFE_MARGIN + " statusBar=" + SQUARE_STATUS_BAR);
console.log("LIVE_C_ROUND " + JSON.stringify(layoutLive(round, "C")));
console.log("EVENT_ROUND " + JSON.stringify(layoutEvent(round)));
console.log("LIVE_A_RECT " + JSON.stringify(layoutLive(rect, "A")));
