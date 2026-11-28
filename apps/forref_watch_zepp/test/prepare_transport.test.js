import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createMemoryProvisionStore, createWatchProvisionAdmission } from "../utils/watch_provision.js";
import { createMemoryTextStore } from "../utils/provision_transport.js";
import { blockedDuringPrepare, runPrepare } from "../utils/provision_bridge.js";

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

test("the prepare build refuses lock and activation before the phone bridge", () => {
  assert.equal(blockedDuringPrepare("SUBMIT_WATCH_LOCK_V1"), true);
  assert.equal(blockedDuringPrepare("REPORT_WATCH_ACTIVATED_V1"), true);
  assert.equal(blockedDuringPrepare("GET_WATCH_PROVISION_V1"), false);
  assert.equal(blockedDuringPrepare("PING"), false);
  assert.equal(side.indexOf("replyLink") < side.indexOf("blockedDuringPrepare"), true);
  assert.equal(side.indexOf("blockedDuringPrepare") < side.indexOf("dispatchSideRequest"), true);
  assert.equal(page.includes("runPrepare"), true);
  assert.equal(page.includes("runHandshake"), false);
  assert.equal(page.includes("SUBMIT_WATCH_LOCK_V1"), false);
  assert.equal(page.includes("REPORT_WATCH_ACTIVATED_V1"), false);
  assert.equal(page.includes("homeName"), false);
  assert.equal(page.includes("canonical="), true);
  assert.equal(page.includes("onDestroy()"), true);
  assert.equal(page.includes("clock_"), false);
  assert.equal(app.includes("App({"), true);
  assert.equal(app.includes("@zeppos/zml"), false);
  assert.equal(app.includes("startForegroundClock"), true);
});
