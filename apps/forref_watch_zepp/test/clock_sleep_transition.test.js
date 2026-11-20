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
  noteRecover,
  noteServiceTick,
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
  assert.equal(witness.offTicks, 5);
  assert.equal(witness.maxDt, 1000);
  assert.equal(witness.lastCheckpointUtc, T0 + 5000);
  assert.equal(displayText({ unverified: false, digits: "00:05", added: false }), "00:05");
  const restored = loadSession(store, EPOCH, utc + 1000);
  assert.equal(restored.reason, "CONTINUITY_RESUMED");
  witness = noteRecover(witness, restored.reason);
  const line = formatWitness(witness, utc + 1000);
  assert.equal(line.includes("off=5"), true);
  assert.equal(line.includes("max=1000"), true);
  assert.equal(line.includes("ck=1000"), true);
  assert.equal(line.includes("r=CONTINUITY_RESUMED"), true);
});

test("a screen-on service tick does not write and does not count as an off tick", () => {
  const noted = noteServiceTick(emptyWitness(), {
    screen: "on",
    dt: 1000,
    class: "CHAIN",
    committed: true,
    utc: T0 + 1000,
  });
  assert.equal(noted.write, false);
  assert.equal(noted.witness.offTicks, 0);
  assert.equal(noted.witness.lastCheckpointUtc, null);
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
  assert.equal(noted.write, true);
  assert.equal(noted.witness.offTicks, 1);
  assert.equal(noted.witness.maxDt, 4000);
  assert.equal(noted.witness.lastCheckpointUtc, null);
  const line = formatWitness(noteRecover(noted.witness, "RECOVERY_REQUIRED"), T0 + 4000);
  assert.equal(line.includes("off=1"), true);
  assert.equal(line.includes("max=4000"), true);
  assert.equal(line.includes("ck=none"), true);
  assert.equal(line.includes("r=RECOVERY_REQUIRED"), true);
});

test("a corrupt witness does not become a checkpoint", () => {
  assert.equal(decodeWitness("nope").offTicks, 0);
  assert.equal(decodeWitness('{"v":1}#00000000').lastCheckpointUtc, null);
});

test("the service holds file writes while the screen is on, and the protocol does not require one", () => {
  const service = readFileSync(new URL("../app-service/clock_service.js", import.meta.url), "utf8");
  assert.equal(service.includes('screen !== "off"'), true);
  assert.equal(service.includes("witness=held"), true);
  const protocol = readFileSync(
    new URL("../../../docs/forref-execution/evidence/zepp-clock-sleep-005/HARDWARE_PROTOCOL.md", import.meta.url),
    "utf8"
  );
  assert.equal(protocol.includes("1, 2, 3, 4, and 5"), true);
  assert.equal(/screen=on[^\n]*pair=match/.test(protocol), false);
  assert.equal(protocol.includes("Do not ask the App Service to write a file while the screen is on."), true);
  const foreground = readFileSync(new URL("../utils/clock_foreground_bind.js", import.meta.url), "utf8");
  assert.equal(foreground.includes("sampleFromScheduler"), true);
  assert.equal(foreground.includes("createTimer"), true);
});
