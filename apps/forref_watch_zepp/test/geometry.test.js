import {
  SAFE_MARGIN,
  SQUARE_STATUS_BAR,
  inside,
  layoutStack,
  layoutLive,
  layoutEvent,
  layoutClock,
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

for (let count = 1; count <= 6; count++) {
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

console.log("FORREF_GEOMETRY_TEST pass margin=" + SAFE_MARGIN + " statusBar=" + SQUARE_STATUS_BAR);
console.log("LIVE_C_ROUND " + JSON.stringify(layoutLive(round, "C")));
console.log("EVENT_ROUND " + JSON.stringify(layoutEvent(round)));
console.log("LIVE_A_RECT " + JSON.stringify(layoutLive(rect, "A")));
