import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fresh, transition, phoneTimeChanged, readClock, STATUS } from "../lib/chron004.js";
import { SLOT_A, SLOT_B, commit, load } from "../lib/dual_slot.js";
import { layoutChron, layoutFits } from "../lib/layout.js";

const t0 = Date.UTC(2026, 10, 21, 12, 0, 0);
const start = () => transition(fresh(), "KICK_OFF", t0).record;

function mem() {
  const box = {};
  return {
    box,
    read(name) {
      return box[name] || "";
    },
    write(name, data) {
      box[name] = data;
    },
  };
}

for (const seconds of [30, 120, 600]) {
  test("sleep gap " + seconds + "s reconstructed from UTC anchor, not callbacks", () => {
    const record = start();
    const view = readClock(record, t0 + seconds * 1000);
    assert.equal(view.display, seconds === 600 ? "10:00" : seconds === 120 ? "02:00" : "00:30");
    assert.equal(view.status, "UTC_ASSUMED");
  });
}

test("documented gap: civil clock step during sleep remains undetectable", () => {
  const record = start();
  const view = readClock(record, t0 + 12 * 60 * 1000);
  assert.equal(view.display, "12:00");
  assert.equal(view.status, "UTC_ASSUMED");
});

test("observed phone time correction fails closed", () => {
  const record = start();
  const changed = phoneTimeChanged(record).record;
  assert.equal(readClock(changed, t0 + 60000).status, "TIME_UNKNOWN");
  assert.equal(changed.reason, "PHONE_TIME_SETTING");
});

test("backward jump and unsafe future are explicit unknown", () => {
  assert.equal(readClock(start(), t0 - 30000).reason, "CLOCK_BACKWARD");
  assert.equal(readClock(start(), t0 + 7 * 3600000).reason, "SEGMENT_OUTSIDE_TRIAL_WINDOW");
});

test("pause, halftime and second half do not count paused interval", () => {
  let record = start();
  record = transition(record, "PAUSE", t0 + 600000).record;
  assert.equal(readClock(record, t0 + 1800000).display, "10:00");
  record = transition(record, "RESUME", t0 + 2400000).record;
  record = transition(record, "PAUSE", t0 + 2700000).record;
  assert.equal(readClock(record, t0 + 2700000).display, "15:00");
  record = transition(record, "END_FIRST_HALF", t0 + 2700000).record;
  assert.equal(record.phase, STATUS.HALF_TIME);
  assert.equal(readClock(record, t0 + 4000000).display, "15:00");
  record = transition(record, "START_SECOND_HALF", t0 + 4000000).record;
  assert.equal(readClock(record, t0 + 4000000 + 20 * 60000).display, "65:00");
});

test("durable two-slot readback survives one damaged slot", () => {
  const io = mem();
  const running = start();
  assert.equal(commit(io, running).ok, true);
  const pause = transition(running, "PAUSE", t0 + 30000).record;
  assert.equal(commit(io, pause).ok, true);
  assert.equal(load(io).record.seq, 2);
  io.box[SLOT_A] = "broken-write";
  assert.equal(load(io).record.seq, 1);
  assert.equal(load(io).reason, "SINGLE_SLOT");
  assert.ok(io.box[SLOT_B]);
});

test("stale write is refused; corrupt records never accepted", () => {
  const io = mem();
  const running = start();
  assert.equal(commit(io, running).ok, true);
  assert.equal(commit(io, running).reason, "NON_MONOTONIC_SEQ");
  io.box[SLOT_B] = "broken";
  assert.equal(load(io).ok, false);
  assert.equal(load(io).reason, "CORRUPT");
});

test("restart restores same anchor instead of resetting it", () => {
  const io = mem();
  const record = start();
  commit(io, record);
  const reread = load(io);
  assert.equal(reread.ok, true);
  assert.equal(readClock(reread.record, t0 + 600000).display, "10:00");
  assert.equal(reread.record.anchorUtc, t0);
});

test("two corrupt slots fail closed rather than creating fresh match", () => {
  const io = mem();
  io.box[SLOT_A] = "torn";
  io.box[SLOT_B] = "torn";
  assert.equal(load(io).reason, "CORRUPT");
  assert.equal(commit(io, start()).reason, "CORRUPT");
});

test("reconstructed time is never labeled PROVEN_TIME", () => {
  const view = readClock(start(), t0 + 1000);
  assert.equal(view.status, "UTC_ASSUMED");
  assert.notEqual(view.status, "PROVEN_TIME");
  assert.equal(phoneTimeChanged(start()).record.integrity, "TIME_UNKNOWN");
});

test("Bip 6 layout stays below the status bar and inside 390x450", () => {
  const laid = layoutChron(390, 450);
  const boxes = [laid.title, laid.clock, laid.status, laid.detail, laid.diagnostic, laid.primary, laid.secondary];
  for (const box of boxes) {
    assert.equal(layoutFits(box, 390, 450), true);
  }
  assert.equal(laid.background.w, 390);
  assert.equal(laid.background.h, 450);
  assert.ok(laid.diagnostic.y + laid.diagnostic.h <= laid.primary.y);
  assert.ok(laid.clock.w >= 300);
  assert.equal(laid.primary.y + laid.primary.h <= 442, true);
});

test("probe identity stays off production app 29566", () => {
  const app = JSON.parse(readFileSync(new URL("../app.json", import.meta.url), "utf8"));
  const page = readFileSync(new URL("../page/gt/home/index.page.js", import.meta.url), "utf8");
  assert.equal(app.app.appId, 30104);
  assert.equal(app.targets.gt.designWidth, 390);
  assert.deepEqual(app.permissions, ["data:os.device.info"]);
  assert.equal(page.includes("match_clock"), false);
  assert.equal(page.includes("DISPLAY_CONTINUITY_MS"), false);
  assert.equal(page.includes("PROVEN_TIME"), false);
  assert.equal(page.includes("readFileSync"), true);
  assert.equal(page.includes("setWakeUpRelaunch"), true);
  assert.equal(page.includes("onPhoneTimeSetting"), true);
});
