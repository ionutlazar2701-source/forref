import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createMemoryProvisionStore, createWatchProvisionAdmission } from "../utils/watch_provision.js";
import { createMemoryTextStore } from "../utils/provision_transport.js";
import {
  GET_WATCH_PROVISION_V1,
  REPORT_WATCH_ACTIVATED_V1,
  SUBMIT_WATCH_LOCK_V1,
  acceptPrepared,
  loadCorrelation,
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

test("the side module does not carry a fixture or the clock service", () => {
  const side = readFileSync(new URL("../app-side/index.js", import.meta.url), "utf8");
  const clock = readFileSync(new URL("../app-service/clock_service.js", import.meta.url), "utf8");
  assert.equal(side.includes("clock_service"), false);
  assert.equal(side.includes("team-alpha"), false);
  assert.equal(side.includes("MatchConfigurationPayload"), false);
  assert.equal(side.includes("disposition: \"unavailable\""), true);
  assert.equal(clock.includes("provision_bridge"), false);
});
