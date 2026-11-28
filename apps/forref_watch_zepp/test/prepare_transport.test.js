import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createMemoryProvisionStore, createWatchProvisionAdmission } from "../utils/watch_provision.js";
import { createMemoryTextStore } from "../utils/provision_transport.js";
import {
  acceptPrepared,
  blockedDuringPrepare,
  classifyFetchFailure,
  classifySideFailure,
  dispatchSideRequest,
  readProvisionEvidence,
  runPrepare,
} from "../utils/provision_bridge.js";

const fixture = JSON.parse(readFileSync(new URL("../../../packages/forref_match_core/test/fixtures/watch_provision_v1.json", import.meta.url), "utf8"));
const document = JSON.parse(fixture.canonical);
const installationId = fixture.localInstallationId;
const requestId = "11111111-2222-4333-8444-555555555555";
const page = readFileSync(new URL("../page/gt/provision/index.page.js", import.meta.url), "utf8");
const side = readFileSync(new URL("../app-side/index.js", import.meta.url), "utf8");
const app = readFileSync(new URL("../app.js", import.meta.url), "utf8");

function preparedBody() {
  return {
    disposition: "prepared",
    schema: "forref.watch-provision.v1",
    matchId: document.matchId,
    contentHash: fixture.contentHash,
    installationId: installationId,
    requestId: requestId,
    generation: 1,
    canonical: fixture.canonical,
    homeName: document.teams.home.name,
    awayName: document.teams.away.name,
    saved: false,
    d1Certified: false,
  };
}

function deps(request) {
  return {
    loadInstallation: () => ({ ok: true, id: installationId, reason: "" }),
    requestStore: createMemoryTextStore(),
    admission: createWatchProvisionAdmission(createMemoryProvisionStore()),
    allocate: () => requestId,
    request: request,
  };
}

test("prepare checks the document bindings and does not lock or activate", async () => {
  const calls = [];
  const bridge = deps((message) => {
    calls.push(message.method);
    return Promise.resolve(preparedBody());
  });
  const result = await runPrepare(bridge);
  assert.equal(result.ok, true);
  assert.equal(result.transport, "prepared");
  assert.equal(result.stage, "prepared");
  assert.equal(result.durable, false);
  assert.equal(result.installationId, installationId);
  assert.equal(result.requestId, requestId);
  assert.equal(result.matchId, document.matchId);
  assert.equal(result.contentHash, fixture.contentHash);
  assert.equal(result.homeName, "North");
  assert.equal(result.awayName, "South");
  assert.deepEqual(calls, ["GET_WATCH_PROVISION_V1"]);
  const again = await runPrepare(bridge);
  assert.equal(again.ok, true);
  assert.equal(again.requestId, requestId);
  assert.equal(again.matchId, document.matchId);
  assert.equal(again.contentHash, fixture.contentHash);
  assert.deepEqual(calls, ["GET_WATCH_PROVISION_V1", "GET_WATCH_PROVISION_V1"]);
});

test("a canonical document that disagrees with the watch is refused", async () => {
  const calls = [];
  const body = preparedBody();
  body.contentHash = "a".repeat(64);
  const result = await runPrepare(deps((message) => {
    calls.push(message.method);
    return Promise.resolve(body);
  }));
  assert.equal(result.ok, false);
  assert.equal(result.reason, "binding");
  assert.equal(result.durable, false);
  assert.deepEqual(calls, ["GET_WATCH_PROVISION_V1"]);
});

test("the diagnostic build reads stored evidence and does not run the handshake", () => {
  assert.equal(blockedDuringPrepare("SUBMIT_WATCH_LOCK_V1"), true);
  assert.equal(blockedDuringPrepare("REPORT_WATCH_ACTIVATED_V1"), true);
  assert.equal(blockedDuringPrepare("GET_WATCH_PROVISION_V1"), false);
  assert.equal(side.includes("blockedDuringPrepare"), true);
  assert.equal(side.includes("prepare-only"), true);
  assert.equal(side.indexOf("replyLink") < side.indexOf("GET_SIDE_BUILD_V1"), true);
  assert.equal(side.indexOf("GET_SIDE_BUILD_V1") < side.indexOf("PROBE_BRIDGE_V1"), true);
  assert.equal(side.indexOf("PROBE_BRIDGE_V1") < side.indexOf("blockedDuringPrepare"), true);
  assert.equal(side.indexOf("blockedDuringPrepare") < side.indexOf("dispatchSideRequest"), true);
  assert.equal(page.includes("readProvisionEvidence"), true);
  assert.equal(page.includes("runPrepare"), true);
  assert.equal(page.includes("runSideDiagnostic"), false);
  assert.equal(page.includes("runHandshake"), false);
  assert.equal(page.includes("durablePath"), true);
  assert.equal(page.includes("deviceBuildLine"), true);
  assert.equal(page.indexOf("readProvisionEvidence") < page.indexOf("start() {"), true);
  assert.equal(page.slice(page.indexOf("build() {"), page.indexOf("start() {")).includes("attachDeviceMessaging"), false);
  assert.equal(page.includes("SUBMIT_WATCH_LOCK_V1"), false);
  assert.equal(page.includes("REPORT_WATCH_ACTIVATED_V1"), false);
  assert.equal(page.includes("homeName"), false);
  assert.equal(page.includes("canonical="), true);
  assert.equal(page.includes("hop="), true);
  assert.equal(page.includes("device:messaging"), true);
  assert.equal(page.includes("onDestroy()"), true);
  assert.equal(page.includes("clock_"), false);
  assert.equal(app.includes("App({"), true);
  assert.equal(app.includes("@zeppos/zml"), false);
  assert.equal(app.includes("startForegroundClock"), true);
});

test("a transport failure keeps the hop instead of collapsing to unavailable", async () => {
  const result = await runPrepare(deps(() => Promise.resolve({
    disposition: "unavailable",
    reason: "timeout",
    hop: "fetch",
    category: "timeout",
    durable: false,
  })));
  assert.equal(result.ok, false);
  assert.equal(result.reason, "fetch:timeout");
  assert.equal(result.hop, "fetch");
  assert.equal(result.category, "timeout");
  assert.equal(acceptPrepared({ disposition: "unavailable", reason: "timeout" }, installationId, requestId).reason, "timeout");
});

test("side fetch names timeout, refusal, malformed payload, and connection refusal", async () => {
  assert.equal(classifyFetchFailure({ reason: "deadline" }), "timeout");
  assert.equal(classifyFetchFailure(new Error("connect ECONNREFUSED 127.0.0.1:47221")), "connection-refused");
  assert.equal(classifyFetchFailure(new Error("permission denied")), "permission");
  assert.equal(classifyFetchFailure(new Error("socket hang up")), "transport");
  const request = {
    method: "GET_WATCH_PROVISION_V1",
    params: { installationId: installationId, requestId: requestId, generation: 1 },
  };
  const refused = await dispatchSideRequest(request, () => Promise.resolve({
    status: 409,
    body: JSON.stringify({ disposition: "refused", reason: "installation", canonical: fixture.canonical }),
  }));
  assert.equal(refused.hop, "bridge");
  assert.equal(refused.category, "http-refusal");
  assert.equal(refused.reason, "installation");
  assert.equal(JSON.stringify(refused).includes(fixture.canonical), false);
  const denied = await dispatchSideRequest(request, () => Promise.resolve({ status: 403, body: "{}" }));
  assert.equal(denied.category, "permission");
  assert.equal(classifySideFailure(null, { httpStatus: 200, reason: "malformed", disposition: "unavailable" }).hop, "normalize");
  const broken = await dispatchSideRequest(request, () => Promise.resolve({ status: 200, body: "not-json" }));
  assert.equal(broken.hop, "normalize");
  assert.equal(broken.category, "malformed");
  const down = await dispatchSideRequest(request, () => Promise.reject(new Error("connect ECONNREFUSED 127.0.0.1:47221")));
  assert.equal(down.hop, "fetch");
  assert.equal(down.category, "connection-refused");
  assert.equal(down.reason, "connection-refused");
  const timed = await dispatchSideRequest(request, () => Promise.reject({ reason: "deadline" }));
  assert.equal(timed.category, "timeout");
  assert.equal(timed.reason, "timeout");
});

test("stored evidence is read without writing a new request", async () => {
  const bridge = deps(() => Promise.resolve(preparedBody()));
  const prepared = await runPrepare(bridge);
  assert.equal(prepared.ok, true);
  const before = bridge.requestStore.read().text;
  const evidence = readProvisionEvidence(
    { ok: true, id: installationId },
    bridge.requestStore,
    bridge.admission,
  );
  assert.equal(bridge.requestStore.read().text, before);
  assert.equal(evidence.installation, installationId);
  assert.equal(evidence.request, requestId);
  assert.equal(evidence.match, document.matchId);
  assert.equal(evidence.hash, fixture.contentHash);
  assert.equal(evidence.generation, 1);
  assert.equal(evidence.phase, "verified");
  assert.equal(evidence.canonical, "accepted");
  assert.equal(evidence.readback, 1);
  assert.equal(evidence.durable, 1);
  assert.equal(evidence.lock, 0);
  assert.equal(evidence.activation, 0);
  assert.equal(evidence.wrote, 0);
  assert.equal(evidence.line.includes(fixture.canonical), false);
  assert.equal(evidence.line.includes("North"), false);
  const empty = createMemoryTextStore();
  let writes = 0;
  const guarded = {
    read() {
      return empty.read();
    },
    write() {
      writes += 1;
      return { status: "ok" };
    },
  };
  const blank = readProvisionEvidence(
    { ok: true, id: installationId },
    guarded,
    createWatchProvisionAdmission(createMemoryProvisionStore()),
  );
  assert.equal(writes, 0);
  assert.equal(blank.phase, "absent");
  assert.equal(blank.lock, 0);
  assert.equal(blank.activation, 0);
});
