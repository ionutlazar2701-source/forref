import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  DISPLAY_CONTINUITY_MS,
  Trust,
  applyIntent,
  displayText,
  freshSession,
  liveFrame,
  loadSession,
} from "../utils/match_clock.js";
import { runServiceTick } from "../utils/clock_service_core.js";
import {
  decodeWitness,
  emptyWitness,
  encodeWitness,
  formatWitness,
  noteFault,
  noteLife,
  noteRecover,
  noteServiceTick,
  noteWrite,
} from "../utils/clock_sleep_witness.js";

const EPOCH = "epoch-a";
const T0 = 1_700_000_000_000;
const root = new URL("../", import.meta.url);

function kick(at) {
  const started = applyIntent(freshSession(), "KICK_OFF", {
    utcMillis: at,
    epoch: EPOCH,
    intentId: "kick",
  });
  assert.equal(started.ok, true);
  return started.session;
}

function mirrorOnly() {
  const box = { file: "", mirror: "" };
  return {
    writeFile(raw) {
      box.file = raw;
      return true;
    },
    readFile() {
      return box.file;
    },
    writeMirror(raw) {
      box.mirror = raw;
      return true;
    },
    readMirror() {
      return box.mirror;
    },
    writeKv() {
      return false;
    },
    readKv() {
      return "";
    },
  };
}

test("the continuity window stays 2.5 seconds", () => {
  assert.equal(DISPLAY_CONTINUITY_MS, 2500);
});

test("one and two seconds with no background tick stay on the foreground checkpoint", () => {
  for (const seconds of [1, 2]) {
    const started = kick(T0);
    const frame = liveFrame(started, T0 + seconds * 1000, EPOCH);
    assert.equal(frame.admitted, true, String(seconds));
    assert.equal(frame.reason, "TICK");
    assert.notEqual(frame.session.trust, Trust.UNVERIFIED);
    assert.equal(displayText(frame.view), "00:0" + seconds);
  }
});

test("three, four, and five seconds with no background tick add no elapsed time", () => {
  for (const seconds of [3, 4, 5]) {
    const started = kick(T0);
    const frame = liveFrame(started, T0 + seconds * 1000, EPOCH);
    assert.equal(frame.reason, "UNSAMPLED_GAP", String(seconds));
    assert.equal(frame.session.trust, Trust.UNVERIFIED);
    assert.equal(frame.session.firstHalfClosedMs, started.firstHalfClosedMs);
    assert.equal(frame.view.digits, null);
    assert.equal(displayText(frame.view), null);
  }
});

test("off-screen ticks through five seconds commit and resume inside the window", () => {
  const store = mirrorOnly();
  let session = kick(T0);
  let witness = emptyWitness();
  let utc = T0;
  for (let second = 1; second <= 5; second += 1) {
    utc += 1000;
    const result = runServiceTick(store, utc, "granted", session);
    assert.equal(result.wrote, true, result.reason);
    const noted = noteServiceTick(witness, {
      screen: "off",
      dt: 1000,
      class: "CHAIN",
      committed: true,
      utc: utc,
    });
    assert.equal(noted.write, true);
    witness = decodeWitness(encodeWitness(noted.witness));
    session = result.session;
  }
  assert.equal(witness.callbacks, 5);
  assert.equal(witness.offTicks, 5);
  assert.equal(witness.maxDt, 1000);
  assert.equal(witness.lastCheckpointUtc, T0 + 5000);
  assert.equal(displayText({ unverified: false, digits: "00:05", added: false }), "00:05");
  const restored = loadSession(store, EPOCH, utc + 1000);
  assert.equal(restored.reason, "CONTINUITY_RESUMED");
  witness = noteLife(witness, { init: true });
  witness = noteWrite(witness, { ok: true, readback: true });
  witness = noteRecover(witness, restored.reason);
  const line = formatWitness(witness, utc + 1000);
  assert.equal(line.includes("L=CHAIN"), true);
  assert.equal(line.includes("n=5"), true);
  assert.equal(line.includes("x=1000"), true);
  assert.equal(line.includes("ck=1000"), true);
  assert.equal(line.includes("r=CONTINUITY_RESUMED"), true);
});

test("a screen-on callback is counted and is not an off tick", () => {
  const noted = noteServiceTick(emptyWitness(), {
    screen: "on",
    dt: 1000,
    class: "CHAIN",
    committed: true,
    utc: T0 + 1000,
  });
  assert.equal(noted.witness.callbacks, 1);
  assert.equal(noted.witness.maxDt, 1000);
  assert.equal(noted.witness.offTicks, 0);
  assert.equal(noted.witness.lastScreen, "on");
  assert.equal(noted.witness.lastCheckpointUtc, T0 + 1000);
});

test("a four second off callback is recorded and does not move the checkpoint", () => {
  const started = kick(T0);
  const frame = liveFrame(started, T0 + 4000, EPOCH);
  const noted = noteServiceTick(emptyWitness(), {
    screen: "off",
    dt: 4000,
    class: "TIMER_GAP",
    committed: false,
    utc: T0 + 4000,
  });
  assert.equal(frame.reason, "UNSAMPLED_GAP");
  assert.equal(frame.session.firstHalfClosedMs, 0);
  assert.equal(noted.witness.callbacks, 1);
  assert.equal(noted.witness.offTicks, 1);
  assert.equal(noted.witness.maxDt, 4000);
  assert.equal(noted.witness.lastCheckpointUtc, null);
  const recorded = noteWrite(noteLife(noteFault(noted.witness, frame.reason), { init: true }), {
    ok: true,
    readback: true,
  });
  const line = formatWitness(recorded, T0 + 4000);
  assert.equal(line.includes("L=GAP"), true);
  assert.equal(line.includes("n=1"), true);
  assert.equal(line.includes("x=4000"), true);
  assert.equal(line.includes("ck=none"), true);
  assert.equal(line.includes("r=UNSAMPLED_GAP"), true);
});

test("a corrupt witness does not become a checkpoint", () => {
  assert.equal(decodeWitness("nope").offTicks, 0);
  assert.equal(decodeWitness('{"v":1}#00000000').lastCheckpointUtc, null);
});

test("the foreground sampler stays in place and the callback is counted before the screen read", () => {
  const service = readFileSync(new URL("../app-service/clock_service.js", import.meta.url), "utf8");
  const countAt = service.indexOf("ledger = noteCallback(ensureLedger(), dt);");
  const screenAt = service.indexOf("const screen = screenNow();");
  assert.equal(countAt > 0 && screenAt > countAt, true);
  assert.equal(service.includes("createSysTimer"), true);
  assert.equal(service.includes("runServiceTick"), true);
  const foreground = readFileSync(new URL("../utils/clock_foreground_bind.js", import.meta.url), "utf8");
  assert.equal(foreground.includes("sampleFromScheduler"), true);
  assert.equal(foreground.includes("createTimer"), true);
});
