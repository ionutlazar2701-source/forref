import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DISPLAY_CONTINUITY_MS } from "../utils/match_clock.js";
import {
  emptyWitness,
  encodeWitness,
  decodeWitness,
  executionLink,
  formatWitness,
  mergeServiceLedger,
  noteAdmit,
  noteCallback,
  noteCheckpoint,
  noteFault,
  noteHost,
  noteLife,
  noteScreen,
  noteWrite,
  sameEvidence,
} from "../utils/clock_sleep_witness.js";

const T0 = 1_700_000_000_000;

test("the 1.0.8 reading has no durable service execution", () => {
  const now = T0 + 20653;
  let witness = noteHost(emptyWitness(), { startClass: "ok", running: true });
  witness = noteAdmit(witness, "HELD");
  witness = noteCheckpoint(witness, now - 20653);
  assert.equal(executionLink(witness), "SERVICE");
  assert.equal(witness.callbacks, 0);
  assert.equal(witness.maxDt, 0);
  assert.equal(witness.initSeen, false);
  const line = formatWitness(witness, now);
  assert.equal(line.includes("L=SERVICE"), true);
  assert.equal(line.includes("S=ok"), true);
  assert.equal(line.includes("I=0"), true);
  assert.equal(line.includes("n=0"), true);
  assert.equal(line.includes("x=0"), true);
  assert.equal(line.includes("ck=20653"), true);
  assert.equal(line.includes("r=HELD"), true);
  assert.equal(DISPLAY_CONTINUITY_MS, 2500);
});

test("a later HELD sample does not replace the first gap", () => {
  let witness = noteAdmit(emptyWitness(), "UNSAMPLED_GAP");
  witness = noteAdmit(witness, "HELD");
  witness = noteAdmit(witness, "HELD");
  assert.equal(witness.fault, "UNSAMPLED_GAP");
  assert.equal(witness.admit, "UNSAMPLED_GAP");
  assert.equal(formatWitness(witness, T0).includes("r=UNSAMPLED_GAP"), true);
  const healthy = noteAdmit(noteAdmit(emptyWitness(), "HELD"), "TICK");
  assert.equal(healthy.fault, "");
  assert.equal(healthy.admit, "TICK");
});

test("the callback count and the maximum delta move before the screen is known", () => {
  let witness = noteCallback(emptyWitness(), null);
  witness = noteCallback(witness, 4000);
  assert.equal(witness.callbacks, 2);
  assert.equal(witness.maxDt, 4000);
  assert.equal(witness.lastScreen, "");
  assert.equal(witness.offTicks, 0);
  assert.equal(witness.lastCheckpointUtc, null);
  witness = noteScreen(witness, "unk:4");
  assert.equal(witness.lastScreen, "unk:4");
  assert.equal(witness.offTicks, 0);
  witness = noteScreen(witness, "fail");
  assert.equal(witness.lastScreen, "fail");
  witness = noteScreen(witness, "off");
  assert.equal(witness.offTicks, 1);
});

test("a write attempt, a successful write, and a readback are separate", () => {
  let witness = noteLife(noteCallback(emptyWitness(), 1000), { init: true });
  witness = noteWrite(witness, { ok: false, readback: false });
  assert.equal(executionLink(witness), "WRITE");
  witness = noteWrite(witness, { ok: true, readback: false });
  assert.equal(executionLink(witness), "READ");
  witness = noteWrite(witness, { ok: true, readback: true });
  assert.equal(witness.writeAttempts, 3);
  assert.equal(witness.writeOk, 2);
  assert.equal(witness.readbackOk, 1);
  assert.equal(executionLink(witness), "CHAIN");
  const line = formatWitness(witness, T0);
  assert.equal(line.includes("w=3/2/1"), true);
  assert.equal(line.includes("I=1"), true);
});

test("init without a callback is a silent timer, and a gap stays closed", () => {
  const started = noteLife(emptyWitness(), { init: true });
  assert.equal(executionLink(started), "TIMER");
  let witness = noteCallback(started, 1000);
  witness = noteCallback(witness, 5000);
  witness = noteWrite(witness, { ok: true, readback: true });
  assert.equal(witness.lastCheckpointUtc, null);
  assert.equal(executionLink(witness), "GAP");
  witness = noteFault(witness, "UNSAMPLED_GAP");
  witness = noteAdmit(witness, "HELD");
  assert.equal(formatWitness(witness, T0).includes("r=UNSAMPLED_GAP"), true);
  assert.equal(witness.maxDt, 5000);
});

test("a service merge keeps the first fault and the durable counters", () => {
  const file = noteAdmit(noteHost(emptyWitness(), { startClass: "ok", running: true }), "HELD");
  let local = noteLife(noteCallback(emptyWitness(), 1000), { init: true });
  local = noteScreen(local, "off");
  local = noteFault(local, "UNSAMPLED_GAP");
  local = noteWrite(local, { ok: true, readback: true });
  const merged = mergeServiceLedger(file, local);
  assert.equal(merged.startClass, "ok");
  assert.equal(merged.admit, "HELD");
  assert.equal(merged.fault, "UNSAMPLED_GAP");
  assert.equal(merged.callbacks, 1);
  assert.equal(merged.initSeen, true);
  assert.equal(sameEvidence(merged, local), true);
  const round = decodeWitness(encodeWitness(merged));
  assert.equal(round.fault, "UNSAMPLED_GAP");
  assert.equal(round.callbacks, 1);
  assert.equal(round.writeOk, 1);
});

test("the five-second protocol does not require a screen-on write to succeed", () => {
  const protocol = readFileSync(
    new URL("../../../docs/forref-execution/evidence/zepp-clock-sleep-006/HARDWARE_PROTOCOL.md", import.meta.url),
    "utf8"
  );
  assert.equal(protocol.includes("exactly 5 seconds"), true);
  assert.equal(protocol.includes("Do not require an App Service file write to succeed while the screen is on."), true);
  assert.equal(/screen=on[^\n]*pair=match/.test(protocol), false);
});
