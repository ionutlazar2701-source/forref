import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { createMemoryProvisionStore, createWatchProvisionAdmission } from "../utils/watch_provision.js";
import { createMemoryTextStore } from "../utils/provision_transport.js";
import {
  GET_WATCH_PROVISION_V1,
  REPORT_WATCH_ACTIVATED_V1,
  SUBMIT_WATCH_LOCK_V1,
  acceptPrepared,
  answerFromTransport,
  fetchWithDeadline,
  loadCorrelation,
  normalizeTransportResponse,
  readTransportPayload,
  runHandshake,
  sideFetchBody,
} from "../utils/provision_bridge.js";

const fixture = JSON.parse(readFileSync(new URL("../../../packages/forref_match_core/test/fixtures/watch_provision_v1.json", import.meta.url), "utf8"));
const installationId = fixture.localInstallationId;
const requestId = "11111111-2222-4333-8444-555555555555";

function preparedBody() {
  const document = JSON.parse(fixture.canonical);
  return {
    disposition: "prepared",
    schema: "forref.watch-provision.v1",
    matchId: document.matchId,
    contentHash: fixture.contentHash,
    installationId: installationId,
    requestId: requestId,
    generation: 1,
    canonical: fixture.canonical,
  };
}

function deps(answers) {
  const calls = [];
  return {
    calls: calls,
    loadInstallation: () => ({ ok: true, id: installationId, reason: "" }),
    requestStore: createMemoryTextStore(),
    admission: createWatchProvisionAdmission(createMemoryProvisionStore()),
    allocate: () => requestId,
    request(message) {
      calls.push(message);
      const answer = answers[calls.length - 1];
      if (answer instanceof Error) throw answer;
      return Promise.resolve(answer);
    },
  };
}

test("a missing phone does not invent a configuration", async () => {
  const bridge = deps([new Error("down")]);
  const result = await runHandshake(bridge);
  assert.equal(result.ok, false);
  assert.equal(result.stage, "transport");
  assert.equal(result.transport, "unavailable");
  assert.equal(bridge.admission.loadDurable(installationId, false).canonical, "");
  assert.equal(bridge.calls.length, 1);
  assert.equal(bridge.calls[0].method, GET_WATCH_PROVISION_V1);
});

test("the handshake verifies, locks from the phone durable flag, and activates", async () => {
  const bridge = deps([
    preparedBody(),
    {
      disposition: "locked",
      durable: true,
      matchId: "match-watch-001",
      contentHash: fixture.contentHash,
      installationId: installationId,
      requestId: requestId,
      generation: 1,
    },
    { disposition: "recorded" },
  ]);
  const result = await runHandshake(bridge);
  assert.equal(result.ok, true);
  assert.equal(result.stage, "activated");
  assert.equal(result.homeName, "North");
  assert.equal(result.awayName, "South");
  assert.equal(result.durable, true);
  assert.equal(bridge.admission.loadDurable(installationId, false).state, "WATCH_ACTIVATED");
  assert.equal(bridge.calls[1].method, SUBMIT_WATCH_LOCK_V1);
  assert.equal(bridge.calls[1].params.readBack, true);
  assert.equal(bridge.calls[2].method, REPORT_WATCH_ACTIVATED_V1);
  assert.equal(bridge.calls[1].params.canonical, undefined);
});

test("a lock without durable true does not activate", async () => {
  const bridge = deps([
    preparedBody(),
    {
      disposition: "locked",
      durable: false,
      reason: "transport-unavailable",
      matchId: "match-watch-001",
      contentHash: fixture.contentHash,
      installationId: installationId,
      requestId: requestId,
      generation: 1,
    },
  ]);
  const result = await runHandshake(bridge);
  assert.equal(result.ok, false);
  assert.equal(result.stage, "verified");
  assert.equal(bridge.admission.loadDurable(installationId, false).state, "WATCH_CONFIG_VERIFIED");
  assert.equal(bridge.calls.length, 2);
});

test("a delayed lock for another hash is refused and the retry keeps the correlation", async () => {
  const bridge = deps([
    preparedBody(),
    {
      disposition: "locked",
      durable: true,
      matchId: "match-watch-001",
      contentHash: "f".repeat(64),
      installationId: installationId,
      requestId: requestId,
      generation: 1,
    },
  ]);
  const first = await runHandshake(bridge);
  assert.equal(first.ok, false);
  assert.equal(first.reason, "binding");
  assert.equal(bridge.admission.loadDurable(installationId, false).state, "WATCH_CONFIG_VERIFIED");
  const again = loadCorrelation(bridge.requestStore, installationId);
  assert.equal(again.requestId, requestId);
});

test("the side request does not attach a canonical document", () => {
  const body = sideFetchBody(GET_WATCH_PROVISION_V1, {
    installationId: installationId,
    requestId: requestId,
    generation: 1,
  });
  assert.equal(body.operation, "pending");
  assert.equal(Object.hasOwn(body, "canonical"), false);
  const rejected = acceptPrepared({ disposition: "prepared", payloadVersion: 1, canonical: fixture.canonical }, installationId, requestId);
  assert.equal(rejected.ok, false);
  assert.equal(rejected.reason, "payload");
});

function lockedBody(hash) {
  return {
    disposition: "locked",
    durable: true,
    matchId: "match-watch-001",
    contentHash: hash || fixture.contentHash,
    installationId: installationId,
    requestId: requestId,
    generation: 1,
  };
}

test("the side module does not carry a fixture or the clock service", () => {
  const side = readFileSync(new URL("../app-side/index.js", import.meta.url), "utf8");
  const clock = readFileSync(new URL("../app-service/clock_service.js", import.meta.url), "utf8");
  const live = readFileSync(new URL("../page/gt/live/index.page.js", import.meta.url), "utf8");
  const app = readFileSync(new URL("../app.js", import.meta.url), "utf8");
  const page = readFileSync(new URL("../page/gt/provision/index.page.js", import.meta.url), "utf8");
  assert.equal(side.includes("clock_service"), false);
  assert.equal(side.includes("team-alpha"), false);
  assert.equal(side.includes("MatchConfigurationPayload"), false);
  assert.equal(side.includes("dispatchSideRequest"), true);
  assert.equal(side.includes("this.fetch"), true);
  const bridgeSource = readFileSync(new URL("../utils/provision_bridge.js", import.meta.url), "utf8");
  assert.equal(bridgeSource.includes("disposition: \"unavailable\""), true);
  assert.equal(bridgeSource.includes("fetchWithDeadline"), true);
  assert.equal(side.includes("timeout: 4000"), false);
  assert.equal(clock.includes("provision_bridge"), false);
  assert.equal(live.includes("runHandshake"), false);
  assert.equal(app.includes("runHandshake"), false);
  assert.equal(page.includes("PROVISION_PAGE_TIMEOUT_MS"), true);
  const zml = new URL("../node_modules/@zeppos/zml/dist/zml-side.js", import.meta.url);
  if (existsSync(zml)) {
    const source = readFileSync(zml, "utf8");
    assert.equal(source.includes("fetch:e=>fetch"), true);
    assert.equal(source.includes("timeout:1e4"), true);
  }
});

test("a JSON string and an HTTP wrapper are accepted only when they agree", async () => {
  const prepared = preparedBody();
  assert.equal(normalizeTransportResponse(JSON.stringify(prepared)).ok, true);
  assert.equal(normalizeTransportResponse({ status: 200, body: JSON.stringify(prepared) }).ok, true);
  assert.equal(normalizeTransportResponse({ statusCode: 200, body: prepared }).disposition, "prepared");
  for (const raw of [
    { status: 409, body: prepared },
    { status: 500, body: { disposition: "prepared", canonical: fixture.canonical } },
    { status: 200, body: "not-json" },
    { status: 200, body: Object.assign({}, prepared, { durable: true }) },
    { disposition: "locked", durable: false },
    null,
  ]) {
    const normalized = normalizeTransportResponse(raw);
    assert.equal(normalized.ok, false, JSON.stringify(raw));
    assert.notEqual(normalized.disposition, "prepared");
    assert.notEqual(normalized.disposition, "locked");
    const bridge = deps([raw]);
    const result = await runHandshake(bridge);
    assert.equal(result.ok, false);
    assert.equal(bridge.admission.loadDurable(installationId, false).canonical, "");
    assert.equal(loadCorrelation(bridge.requestStore, installationId).requestId, requestId);
  }
  const wrapped = await readTransportPayload({
    status: 200,
    text() {
      return Promise.resolve(JSON.stringify(prepared));
    },
  });
  assert.equal(wrapped.ok, true);
  assert.equal(answerFromTransport({ status: 500, body: prepared }).disposition, "unavailable");
});

test("the side deadline rejects a fetch that never returns", async () => {
  let fired = null;
  const hanging = fetchWithDeadline(() => new Promise(() => {}), 4000, {
    schedule(fn) {
      fired = fn;
      return 1;
    },
    cancel() {},
  });
  const failure = hanging.then(() => "resolved", (err) => err.reason);
  fired();
  assert.equal(await failure, "deadline");
});

test("a lost lock response keeps the verified watch and the same request", async () => {
  const bridge = deps([preparedBody(), new Error("lost")]);
  const lost = await runHandshake(bridge);
  assert.equal(lost.ok, false);
  assert.equal(lost.stage, "verified");
  assert.equal(bridge.admission.loadDurable(installationId, false).state, "WATCH_CONFIG_VERIFIED");
  const kept = loadCorrelation(bridge.requestStore, installationId);
  assert.equal(kept.requestId, requestId);
  assert.equal(kept.phase, "verified");
  assert.equal(kept.contentHash, fixture.contentHash);
  assert.equal(kept.matchId, "match-watch-001");
  bridge.request = (message) => {
    bridge.calls.push(message);
    const queue = [preparedBody(), lockedBody(), { disposition: "recorded" }];
    return Promise.resolve(queue[bridge.calls.length - 3]);
  };
  const again = await runHandshake(bridge);
  assert.equal(again.ok, true);
  assert.equal(again.requestId, requestId);
  assert.equal(bridge.admission.loadDurable(installationId, false).state, "WATCH_ACTIVATED");
  assert.equal(loadCorrelation(bridge.requestStore, installationId).phase, "reported");
  const retried = bridge.calls.filter((call) => call.method === SUBMIT_WATCH_LOCK_V1);
  assert.equal(retried.length, 2);
  assert.equal(retried[1].params.requestId, requestId);
  assert.equal(retried[1].params.contentHash, fixture.contentHash);
});

test("a lost activation report stays activated and retries the same identity", async () => {
  const bridge = deps([preparedBody(), lockedBody(), new Error("report-lost")]);
  const lost = await runHandshake(bridge);
  assert.equal(lost.ok, false);
  assert.equal(lost.stage, "report");
  const marker = bridge.admission.loadDurable(installationId, false);
  assert.equal(marker.state, "WATCH_ACTIVATED");
  assert.equal(loadCorrelation(bridge.requestStore, installationId).phase, "activated");
  const before = bridge.requestStore.read().text;
  bridge.request = (message) => {
    bridge.calls.push(message);
    const queue = [preparedBody(), lockedBody(), { disposition: "recorded" }];
    return Promise.resolve(queue[bridge.calls.length - 4]);
  };
  const again = await runHandshake(bridge);
  assert.equal(again.ok, true);
  assert.equal(again.requestId, requestId);
  assert.equal(bridge.admission.loadDurable(installationId, false).state, "WATCH_ACTIVATED");
  assert.equal(loadCorrelation(bridge.requestStore, installationId).requestId, requestId);
  assert.equal(loadCorrelation(bridge.requestStore, installationId).phase, "reported");
  assert.notEqual(before, bridge.requestStore.read().text);
});

test("a late canonical for another match does not replace the correlation", async () => {
  const bridge = deps([preparedBody(), new Error("lost")]);
  await runHandshake(bridge);
  const other = preparedBody();
  other.matchId = "match-other";
  other.contentHash = "a".repeat(64);
  bridge.request = () => Promise.resolve(other);
  const delayed = await runHandshake(bridge);
  assert.equal(delayed.ok, false);
  assert.equal(delayed.reason, "binding");
  const kept = loadCorrelation(bridge.requestStore, installationId);
  assert.equal(kept.requestId, requestId);
  assert.equal(kept.matchId, "match-watch-001");
  assert.equal(kept.contentHash, fixture.contentHash);
  assert.equal(bridge.admission.loadDurable(installationId, false).state, "WATCH_CONFIG_VERIFIED");
});

test("a second handshake waits instead of minting another request", async () => {
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  const bridge = deps([gate, lockedBody(), { disposition: "recorded" }]);
  const first = runHandshake(bridge);
  const second = await runHandshake(bridge);
  assert.equal(second.reason, "busy");
  assert.equal(bridge.calls.length, 1);
  release(preparedBody());
  const done = await first;
  assert.equal(done.ok, true);
  assert.equal(done.requestId, requestId);
  assert.equal(bridge.calls.length, 3);
});

test("diagnostic lines name the operation and omit the canonical", async () => {
  const lines = [];
  const bridge = deps([preparedBody(), lockedBody(), { disposition: "recorded" }]);
  bridge.log = (line) => lines.push(line);
  await runHandshake(bridge);
  assert.equal(lines.some((line) => line.includes("tx=request")), true);
  assert.equal(lines.some((line) => line.includes("tx=response")), true);
  assert.equal(lines.some((line) => line.includes("tx=transition")), true);
  assert.equal(lines.some((line) => line.includes(fixture.canonical)), false);
  assert.equal(lines.some((line) => line.includes("North")), false);
  assert.equal(lines.some((line) => line.includes(requestId)), true);
});
