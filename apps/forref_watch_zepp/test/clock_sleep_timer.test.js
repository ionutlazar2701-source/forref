import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DISPLAY_CONTINUITY_MS, Phase, Trust } from "../utils/match_clock.js";
import { createServiceHost, SERVICE_FILE } from "../utils/clock_service_policy.js";
import {
  emptyWitness,
  encodeWitness,
  decodeWitness,
  formatWitness,
  noteDiagReadback,
  noteExperiment,
  noteExperimentTick,
  noteHost,
  noteLife,
  noteTimer,
  noteWrite,
  sameEvidence,
  timerDiagnosis,
} from "../utils/clock_sleep_witness.js";

function lineOf(witness) {
  const line = formatWitness(witness);
  assert.equal(line.length <= 48, true, line);
  assert.equal(line.includes("UNSAMPLED_GAP"), false, line);
  return line;
}

test("the 1.0.9 line does not identify the timer", () => {
  let witness = noteLife(emptyWitness(), { init: true });
  witness = noteWrite(witness, { ok: false, readback: false });
  witness = noteWrite(witness, { ok: true, readback: true });
  witness = noteHost(witness, { startClass: "ok", running: true });
  assert.equal(witness.initSeen, true);
  assert.equal(witness.callbacks, 0);
  assert.equal(witness.writeAttempts, 2);
  assert.equal(witness.writeOk, 1);
  assert.equal(witness.readbackOk, 1);
  assert.equal(timerDiagnosis(witness), "UNRECORDED");
  assert.equal(lineOf(witness), "T=- id=- D=- F=0 X=- A=- b=0");
  assert.equal(DISPLAY_CONTINUITY_MS, 2500);
});

test("a thrown or empty timer is not created", () => {
  const failed = noteTimer(emptyWitness(), { state: "failed", id: "" });
  assert.equal(timerDiagnosis(failed), "NOT_CREATED");
  assert.equal(lineOf(failed).includes("T=fail"), true);
  const blank = noteTimer(emptyWitness(), { state: "failed", id: "" });
  assert.equal(blank.timerId, "");
});

test("destroy before the first callback is its own result", () => {
  let witness = noteTimer(emptyWitness(), { state: "created", id: 7 });
  witness = noteLife(witness, { destroy: "destroy" });
  witness = noteDiagReadback(witness);
  assert.equal(timerDiagnosis(witness), "DESTROYED_BEFORE_CALLBACK");
  assert.equal(lineOf(witness), "T=ok id=7 D=destroy F=0 X=- A=- b=1");
});

test("a live service with no callback was not delivered", () => {
  let witness = noteTimer(emptyWitness(), { state: "created", id: 4 });
  witness = noteExperiment(witness, { state: "created", id: 9 });
  witness = noteHost(witness, { listed: "yes" });
  witness = noteDiagReadback(witness);
  assert.equal(timerDiagnosis(witness), "NOT_DELIVERED");
  assert.equal(lineOf(witness), "T=ok id=4 D=- F=0 X=0 A=1 b=1");
});

test("the five second experiment can fire while the match timer does not", () => {
  let witness = noteTimer(emptyWitness(), { state: "created", id: 4 });
  witness = noteExperiment(witness, { state: "created", id: 9 });
  witness = noteExperimentTick(witness);
  witness = noteHost(witness, { listed: "yes" });
  assert.equal(witness.callbacks, 0);
  assert.equal(timerDiagnosis(witness), "LONG_PERIOD_ONLY");
  assert.equal(lineOf(witness).includes("X=1"), true);
  assert.equal(lineOf(witness).includes("F=0"), true);
});

test("a missing service after wake is not a delivered callback", () => {
  let witness = noteTimer(emptyWitness(), { state: "created", id: 4 });
  witness = noteHost(witness, { listed: "no" });
  assert.equal(timerDiagnosis(witness), "SERVICE_ABSENT");
  assert.equal(lineOf(witness).includes("A=0"), true);
});

test("the first callback is recorded without granting match time", () => {
  let witness = noteTimer(emptyWitness(), { state: "created", id: 4 });
  witness = noteExperimentTick(noteExperiment(witness, { state: "created", id: 9 }));
  witness.firstCallback = true;
  witness.callbacks = 1;
  assert.equal(timerDiagnosis(witness), "CALLBACK_RECORDED");
  const round = decodeWitness(encodeWitness(witness));
  assert.equal(round.timerId, "4");
  assert.equal(round.firstCallback, true);
  assert.equal(sameEvidence(witness, round), true);
  round.timerId = "8";
  assert.equal(sameEvidence(witness, round), false);
});

test("the service list after wake is yes only when the service file is present", () => {
  const logs = [];
  const present = createServiceHost({
    queryPermission: function () { return [2]; },
    requestPermission: function () { return 2; },
    start: function () { return 0; },
    stop: function () { return 0; },
    getAllAppServices: function () { return [{ file: SERVICE_FILE }]; },
  }, function (line) { logs.push(line); });
  present.sync({ phase: Phase.FIRST_HALF_RUNNING, trust: Trust.OBSERVED });
  assert.equal(present.snapshot().listed, "yes");
  const absent = createServiceHost({
    queryPermission: function () { return [2]; },
    requestPermission: function () { return 2; },
    start: function () { return 0; },
    stop: function () { return 0; },
    getAllAppServices: function () { return []; },
  }, function () {});
  absent.sync({ phase: Phase.FIRST_HALF_RUNNING, trust: Trust.OBSERVED });
  assert.equal(absent.snapshot().listed, "no");
});

test("the match timer stays at one second and the experiment does not sample the match", () => {
  const service = readFileSync(new URL("../app-service/clock_service.js", import.meta.url), "utf8");
  const foreground = readFileSync(new URL("../utils/clock_foreground_bind.js", import.meta.url), "utf8");
  assert.equal(service.includes("createSysTimer(true, 1000, tick)"), true);
  assert.equal(service.includes("createSysTimer(true, 5000, experimentTick)"), true);
  const body = service.slice(service.indexOf("function experimentTick"), service.indexOf("function tick"));
  assert.equal(body.includes("runServiceTick"), false);
  assert.equal(body.includes("liveFrame"), false);
  assert.equal(foreground.includes("sampleFromScheduler"), true);
});
