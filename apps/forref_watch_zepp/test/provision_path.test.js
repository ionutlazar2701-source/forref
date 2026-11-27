import test from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { createMemoryProvisionStore, createWatchProvisionAdmission } from "../utils/watch_provision.js";
import { createMemoryTextStore } from "../utils/provision_transport.js";
import { dispatchSideRequest, runHandshake } from "../utils/provision_bridge.js";

const fixture = JSON.parse(readFileSync(new URL("../../../packages/forref_match_core/test/fixtures/watch_provision_v1.json", import.meta.url), "utf8"));
const document = JSON.parse(fixture.canonical);
const installationId = fixture.localInstallationId;
const requestId = "11111111-2222-4333-8444-555555555555";

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

function listen() {
  const seen = [];
  const server = createServer((req, res) => {
    const chunks = [];
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => {
      const body = JSON.parse(Buffer.concat(chunks).toString("utf8"));
      seen.push({ path: req.url, method: req.method, body });
      let answer = { disposition: "refused", reason: "operation", durable: false };
      let status = 409;
      if (req.url === "/watch-provision/v1" && body.operation === "pending" && body.installationId === installationId) {
        answer = preparedBody();
        status = 200;
      } else if (body.operation === "lock" && body.readBack === true && body.contentHash === fixture.contentHash) {
        answer = {
          disposition: "locked",
          durable: true,
          matchId: document.matchId,
          contentHash: fixture.contentHash,
          installationId: installationId,
          requestId: requestId,
          generation: 1,
          saved: false,
          d1Certified: false,
        };
        status = 200;
      } else if (body.operation === "activation" && body.readBack === true) {
        answer = {
          disposition: "recorded",
          matchId: document.matchId,
          contentHash: fixture.contentHash,
          installationId: installationId,
          requestId: requestId,
          generation: 1,
          saved: false,
          d1Certified: false,
        };
        status = 200;
      }
      res.writeHead(status, { "Content-Type": "application/json" });
      res.end(JSON.stringify(answer));
    });
  });
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      resolve({
        server,
        seen,
        url: "http://127.0.0.1:" + address.port + "/watch-provision/v1",
      });
    });
  });
}

test("a provision request crosses messaging, the side service, and the loopback response", async () => {
  const bridge = await listen();
  const calls = [];
  try {
    const messaging = {
      onCall() {
        return this;
      },
      request(message) {
        calls.push(message.method);
        return dispatchSideRequest(message, (options) => fetch(options.url, {
          method: options.method,
          headers: options.headers,
          body: options.body,
        }), bridge.url);
      },
    };
    const result = await runHandshake({
      loadInstallation: () => ({ ok: true, id: installationId, reason: "" }),
      requestStore: createMemoryTextStore(),
      admission: createWatchProvisionAdmission(createMemoryProvisionStore()),
      allocate: () => requestId,
      request: (message) => messaging.request(message),
    });
    assert.equal(result.ok, true);
    assert.equal(result.transport, "recorded");
    assert.equal(result.contentHash, fixture.contentHash);
    assert.equal(result.homeName, "North");
    assert.equal(result.awayName, "South");
    assert.equal(result.durable, true);
    assert.deepEqual(calls, [
      "GET_WATCH_PROVISION_V1",
      "SUBMIT_WATCH_LOCK_V1",
      "REPORT_WATCH_ACTIVATED_V1",
    ]);
    assert.equal(bridge.seen.length, 3);
    assert.equal(bridge.seen[0].path, "/watch-provision/v1");
    assert.equal(bridge.seen[0].method, "POST");
    assert.equal(bridge.seen[0].body.operation, "pending");
    assert.equal(bridge.seen[1].body.operation, "lock");
    assert.equal(bridge.seen[1].body.readBack, true);
    assert.equal(bridge.seen[2].body.operation, "activation");
    assert.equal(bridge.seen[0].body.canonical, undefined);
  } finally {
    await new Promise((resolve) => bridge.server.close(resolve));
  }
});
