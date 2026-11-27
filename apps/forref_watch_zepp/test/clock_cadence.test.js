import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  classifyCadence,
  createForegroundHost,
  displayedSeconds,
  formatCadence,
  nextTimerDelay,
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
  assert.equal(logged.some((line) => line.includes("wake=open reason=restart")), true);
  now = T0 + 9000;
  armed[1].run();
  assert.equal(faceAt(session, now), "00:09");
  assert.equal(logged.some((line) => line.includes("now=00:09")), true);
  assert.equal(logged.some((line) => line.includes("timer=wake")), true);
  assert.notEqual(host.id(), restarted);
  assert.equal(armed.length, 3);
  assert.equal(stopped.indexOf(restarted) >= 0, true);
  assert.equal(paints, 6);
});

// A repeating timer that was already armed when the screen slept keeps a
// doubled period. A timer created after that mark keeps the delay it was given.
function doublingPlatform(startUtc) {
  let utc = startUtc;
  let seq = 1;
  const live = new Map();
  return {
    utc: function () {
      return utc;
    },
    now: function () {
      return utc;
    },
    delay: function () {
      return nextTimerDelay(utc, 1000);
    },
    arm: function (run, delay) {
      const id = seq;
      seq += 1;
      live.set(id, { run: run, delay: delay, scale: 1 });
      return id;
    },
    disarm: function (id) {
      live.delete(id);
    },
    sleep: function (ms) {
      utc += ms;
      for (const timer of live.values()) {
        timer.scale = 2;
      }
    },
    fire: function () {
      const id = live.keys().next().value;
      const timer = live.get(id);
      const gap = timer.delay * timer.scale;
      utc += gap;
      timer.run();
      return gap;
    },
    liveCount: function () {
      return live.size;
    },
    scale: function () {
      const timer = live.values().next().value;
      return timer ? timer.scale : 0;
    },
  };
}

function paintHost(platform, session, logged) {
  const host = createForegroundHost({
    utc: platform.utc,
    now: platform.now,
    delay: platform.delay,
    sample: function () {
      const view = liveFrame(session, platform.utc(), EPOCH).view;
      view.commitMs = 0;
      return view;
    },
    arm: platform.arm,
    disarm: platform.disarm,
    log: function (line) {
      logged.push(line);
    },
  });
  host.bind(function (view) {
    return { digits: displayText(view), paintMs: 3 };
  });
  host.start();
  return host;
}

test("a timer that survives sleep keeps a 2s callback until it is replaced", () => {
  const session = kick();
  const platform = doublingPlatform(T0);
  const rows = [];
  let previous = null;
  platform.arm(function () {
    const digits = faceAt(session, platform.utc());
    const row = noteCadence(previous, {
      utc: platform.utc(),
      digits: digits,
      prepareMs: 1,
      commitMs: 0,
      paintMs: 1,
    });
    previous = { utc: platform.utc(), digits: digits };
    rows.push(row);
  }, platform.delay());
  platform.fire();
  platform.fire();
  platform.fire();
  platform.sleep(10000);
  const post = [];
  for (let i = 0; i < 6; i++) {
    platform.fire();
    post.push(rows[rows.length - 1]);
    assert.equal(post[post.length - 1].digits, faceAt(session, platform.utc()));
  }
  assert.equal(post[0].digits, "00:15");
  assert.equal(post[0].step, 12);
  assert.equal(post[1].dt, 2000);
  assert.equal(post[1].step, 2);
  assert.equal(classifyCadence(post), "CALLBACK_2S");
  assert.equal(platform.scale(), 2);
  assert.equal(platform.liveCount(), 1);
});

test("replacing the slept timer restores a 1s cadence without moving the anchor", () => {
  for (const slept of [10000, 60000, 300000]) {
    const session = kick();
    const platform = doublingPlatform(T0);
    const logged = [];
    paintHost(platform, session, logged);
    platform.fire();
    platform.fire();
    platform.fire();
    const before = platform.utc();
    platform.sleep(slept);
    const post = [];
    for (let i = 0; i < 8; i++) {
      const gap = platform.fire();
      post.push({ gap: gap, utc: platform.utc(), digits: faceAt(session, platform.utc()) });
      assert.equal(platform.liveCount(), 1);
    }
    assert.equal(post[0].gap, 2000);
    assert.equal(post[0].digits, faceAt(session, before + slept + 2000));
    assert.notEqual(post[0].step, 1);
    for (let i = 1; i < post.length; i++) {
      assert.equal(post[i].gap, 1000);
      assert.equal(post[i].digits, faceAt(session, post[i].utc));
      assert.equal(displayedSeconds(post[i].digits) - displayedSeconds(post[i - 1].digits), 1);
    }
    assert.equal(platform.scale(), 1);
    const wakes = logged.filter(function (line) {
      return line.indexOf("FORREF_CLOCK_WAKE") === 0;
    });
    assert.equal(wakes.length, 8);
    assert.equal(wakes[0].includes("dt="), true);
    assert.equal(wakes[0].includes("step="), true);
    assert.equal(wakes[0].includes("prepareMs="), true);
    assert.equal(wakes[0].includes("commitMs=0"), true);
    assert.equal(wakes[0].includes("paintMs=3"), true);
    assert.equal(wakes[1].includes("dt=1000"), true);
    assert.equal(wakes[1].includes("step=1"), true);
    assert.equal(logged.some(function (line) {
      return line.includes("timer=wake");
    }), true);
    assert.equal(logged.some(function (line) {
      return line.includes("wake=closed");
    }), false);
  }
});

test("returning to Live after sleep leaves one timer on the 1s delay", () => {
  const session = kick();
  const platform = doublingPlatform(T0);
  const logged = [];
  const host = paintHost(platform, session, logged);
  platform.fire();
  platform.fire();
  platform.sleep(10000);
  assert.equal(platform.scale(), 2);
  host.restart();
  assert.equal(platform.liveCount(), 1);
  assert.equal(platform.scale(), 1);
  assert.equal(platform.fire(), 1000);
  assert.equal(faceAt(session, platform.utc()), "00:13");
  assert.equal(platform.liveCount(), 1);
  assert.equal(platform.fire(), 1000);
  assert.equal(faceAt(session, platform.utc()), "00:14");
  assert.equal(logged.some(function (line) {
    return line.includes("wake=open reason=restart");
  }), true);
  assert.equal(logged.some(function (line) {
    return line.includes("page=") || line.includes("writeFile");
  }), false);
});

test("a 1s callback that skips a displayed second does not replace the timer", () => {
  let now = T0;
  let armed = 0;
  const rows = [];
  const host = createForegroundHost({
    utc: function () {
      return now;
    },
    now: function () {
      return now;
    },
    delay: function () {
      return 1000;
    },
    sample: function () {
      const shown = Math.floor((now - T0) / 1000) * 2;
      return { digits: "00:" + String(shown).padStart(2, "0"), commitMs: 0 };
    },
    arm: function () {
      armed += 1;
      return armed;
    },
    disarm: function () {
      throw new Error("must not stop");
    },
    log: function () {},
  });
  host.start();
  for (let second = 1; second <= 5; second++) {
    now = T0 + second * 1000;
    rows.push(host.tick());
  }
  assert.equal(armed, 1);
  assert.equal(host.id(), 1);
  assert.equal(classifyCadence(rows), "RENDER_SKIP");
});

test("a gap does not arm a second timer when the slept timer cannot be stopped", () => {
  let now = 0;
  let armed = 0;
  const host = createForegroundHost({
    utc: function () {
      return now;
    },
    now: function () {
      return now;
    },
    sample: function () {
      return { digits: "00:05", commitMs: 0 };
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
  host.start();
  now = 1000;
  host.tick();
  now = 4000;
  host.tick();
  assert.equal(armed, 1);
  assert.equal(host.id(), 1);
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
  assert.equal(foreground.includes("createTimer(delay, 1000, run)"), true);
  assert.equal(foreground.includes("nextTimerDelay"), true);
  assert.equal(nextTimerDelay(1000, 1000), 1000);
  assert.equal(nextTimerDelay(1500, 1000), 500);
  assert.equal(nextTimerDelay(1960, 1000), 1040);
  assert.equal(nextTimerDelay(null, 1000), 1000);
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
