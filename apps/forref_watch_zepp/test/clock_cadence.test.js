import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  classifyCadence,
  createForegroundHost,
  displayedSeconds,
  formatCadence,
  noteCadence,
  oppositePhaseGaps,
} from "../utils/clock_cadence.js";
import { displayText, liveFrame } from "../utils/match_clock.js";
import { openUtcSession } from "../utils/clock_segment.js";
import { applyIntent } from "../utils/match_clock.js";

const EPOCH = "epoch-a";
const T0 = 1700000000000;

function faceAt(session, utc) {
  return displayText(liveFrame(session, utc, EPOCH).view);
}

function kick() {
  const started = applyIntent(openUtcSession(EPOCH), "KICK_OFF", {
    utcMillis: T0,
    epoch: EPOCH,
    intentId: "kick",
  });
  assert.equal(started.ok, true);
  return started.session;
}

function rowsFrom(dt, step, count) {
  const rows = [{ dt: null, step: null }];
  for (let i = 0; i < count; i++) {
    rows.push({ dt: dt, step: step });
  }
  return rows;
}

test("displayed seconds follow the face, including added time", () => {
  assert.equal(displayedSeconds("00:01"), 1);
  assert.equal(displayedSeconds("45:00"), 45 * 60);
  assert.equal(displayedSeconds("45 + 00:01"), 45 * 60 + 1);
  assert.equal(displayedSeconds("——:——"), null);
});

test("a 2 second callback phase is not a render skip", () => {
  assert.deepEqual(oppositePhaseGaps(1000, 5), [2000, 2000, 2000, 2000]);
  assert.equal(classifyCadence(rowsFrom(2000, 2, 5)), "CALLBACK_2S");
  assert.equal(classifyCadence(rowsFrom(1000, 2, 5)), "RENDER_SKIP");
  assert.equal(classifyCadence(rowsFrom(1000, 1, 5)), "ONE_SECOND");
  const row = noteCadence({ utc: 1000, digits: "00:01" }, { utc: 3000, digits: "00:03", prepareMs: 4, commitMs: 0, paintMs: 2 });
  assert.equal(row.dt, 2000);
  assert.equal(row.step, 2);
  assert.equal(formatCadence(row).includes("timers=1"), true);
  assert.equal(formatCadence(row).includes("prev=00:01"), true);
  assert.equal(formatCadence(row).includes("now=00:03"), true);
});

test("one timer keeps a 1 second face across sleep and navigation restarts", () => {
  const session = kick();
  let now = T0;
  let nextId = 1;
  const stopped = [];
  const armed = [];
  let paints = 0;
  const logged = [];
  const host = createForegroundHost({
    now: function () {
      return now;
    },
    sample: function () {
      const view = liveFrame(session, now, EPOCH).view;
      view.commitMs = 0;
      return view;
    },
    arm: function (run) {
      const id = nextId;
      nextId += 1;
      armed.push({ id: id, run: run });
      return id;
    },
    disarm: function (id) {
      stopped.push(id);
    },
    log: function (line) {
      logged.push(line);
    },
  });
  const first = host.start();
  assert.equal(host.start(), first);
  assert.equal(armed.length, 1);
  const unbind = host.bind(function (view) {
    paints += 1;
    return { digits: displayText(view), paintMs: 1 };
  });
  const cadence = [];
  for (let second = 1; second <= 5; second++) {
    now = T0 + second * 1000;
    armed[0].run();
    const line = logged[logged.length - 1];
    cadence.push(noteCadence(
      second === 1 ? null : { utc: T0 + (second - 1) * 1000, digits: faceAt(session, T0 + (second - 1) * 1000) },
      { utc: now, digits: faceAt(session, now), prepareMs: 0, commitMs: 0, paintMs: 1 }
    ));
    assert.equal(line.includes("now=" + faceAt(session, now)), true, line);
  }
  assert.equal(paints, 5);
  assert.equal(classifyCadence(cadence), "ONE_SECOND");
  unbind();
  now = T0 + 6000;
  armed[0].run();
  assert.equal(paints, 5);
  host.bind(function (view) {
    paints += 1;
    return { digits: displayText(view), paintMs: 2 };
  });
  const restarted = host.restart();
  assert.equal(stopped.indexOf(first) >= 0, true);
  assert.notEqual(restarted, first);
  assert.equal(armed.length, 2);
  now = T0 + 9000;
  armed[1].run();
  assert.equal(faceAt(session, now), "00:09");
  assert.equal(logged[logged.length - 1].includes("now=00:09"), true);
  assert.equal(paints, 6);
});

test("a missed callback shows the anchor second and does not invent the skipped one", () => {
  const session = kick();
  assert.equal(faceAt(session, T0 + 2000), "00:02");
  assert.equal(faceAt(session, T0 + 4000), "00:04");
  const jumped = noteCadence(
    { utc: T0 + 2000, digits: "00:02" },
    { utc: T0 + 4000, digits: faceAt(session, T0 + 4000), prepareMs: 1, commitMs: 0, paintMs: 1 }
  );
  assert.equal(jumped.step, 2);
  assert.equal(jumped.digits, "00:04");
});

test("Live no longer owns a second 1 second timer", () => {
  const live = readFileSync(new URL("../page/gt/live/index.page.js", import.meta.url), "utf8");
  const foreground = readFileSync(new URL("../utils/clock_foreground_bind.js", import.meta.url), "utf8");
  assert.equal(live.includes("createTimer"), false);
  assert.equal(live.includes("bindLivePaint"), true);
  assert.equal(live.includes("restartForegroundClock"), true);
  assert.equal(foreground.includes("createTimer(1000, 1000, run)"), true);
  assert.equal(foreground.includes("sampleFromScheduler"), true);
});

test("a failed stop does not arm a second timer", () => {
  let armed = 0;
  const host = createForegroundHost({
    now: function () {
      return 0;
    },
    sample: function () {
      return { digits: "00:00", commitMs: 0 };
    },
    arm: function () {
      armed += 1;
      return armed;
    },
    disarm: function () {
      throw new Error("stop failed");
    },
    log: function () {},
  });
  const id = host.start();
  assert.equal(host.restart(), id);
  assert.equal(armed, 1);
  assert.equal(host.id(), id);
});
