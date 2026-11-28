import test from "node:test";
import assert from "node:assert/strict";
import { sha256Hex } from "../utils/sha256_hex.js";
import { createMemoryTextStore } from "../utils/provision_transport.js";
import {
  canonicalWatchProvisionV1,
  createMemoryProvisionStore,
  createWatchProvisionAdmission,
} from "../utils/watch_provision.js";
import {
  acceptVerified,
  receiveMatch,
  transferPresentation,
} from "../utils/provision_bridge.js";

const installation = "22222222-2222-4222-8222-222222222222";
const requestId = "44444444-4444-4444-8444-444444444444";
const matchId = "77777777-7777-4777-8777-777777777777";

function document() {
  return {
    matchId: matchId,
    principalId: "ref-1",
    writerDeviceId: installation,
    homeTeamId: "team-north",
    homeName: "North",
    awayTeamId: "team-south",
    awayName: "South",
    halfDurationMs: 2700000,
    provisionVersion: 1,
  };
}

function preparedBody() {
  const canonical = canonicalWatchProvisionV1(document());
  return {
    disposition: "prepared",
    schema: "forref.watch-provision.v1",
    matchId: matchId,
    contentHash: sha256Hex(canonical),
    installationId: installation,
    requestId: requestId,
    generation: 1,
    canonical: canonical,
    homeName: "North",
    awayName: "South",
    saved: false,
    d1Certified: false,
  };
}

function verifiedBody(hash) {
  return {
    disposition: "verified",
    reason: "",
    matchId: matchId,
    contentHash: hash,
    installationId: installation,
    requestId: requestId,
    generation: 1,
    saved: false,
    durable: false,
    d1Certified: false,
  };
}

test("the watch verifies a saved match and retries a dropped acknowledgement", async () => {
  const hash = sha256Hex(canonicalWatchProvisionV1(document()));
  assert.equal(transferPresentation({
    ok: false,
    stage: "transport",
    category: "transport",
  }, 1, 3).done, false);
  assert.equal(acceptVerified(verifiedBody(hash), {
    matchId: matchId,
    contentHash: hash,
    installationId: installation,
    requestId: requestId,
  }).ok, true);
  assert.equal(acceptVerified(verifiedBody("ab"), {
    matchId: matchId,
    contentHash: hash,
    installationId: installation,
    requestId: requestId,
  }).reason, "binding");

  const store = createMemoryProvisionStore();
  let rootWrites = 0;
  const writeRoot = store.writeRoot.bind(store);
  store.writeRoot = (text) => {
    rootWrites += 1;
    return writeRoot(text);
  };
  const calls = [];
  const requestStore = createMemoryTextStore();
  const verified = await receiveMatch({
    attempts: 3,
    wait: () => Promise.resolve(),
    loadInstallation: () => ({ ok: true, id: installation, reason: "" }),
    requestStore: requestStore,
    allocate: () => requestId,
    admission: createWatchProvisionAdmission(store),
    request: (message) => {
      calls.push(message.method);
      const n = calls.length;
      if (n === 1 || n === 3) return Promise.reject(new Error("socket hang up"));
      if (message.method === "GET_WATCH_PROVISION_V1") return Promise.resolve(preparedBody());
      return Promise.resolve(verifiedBody(hash));
    },
  });
  assert.equal(verified.result, "config-verified");
  assert.equal(verified.homeName, "North");
  assert.equal(verified.awayName, "South");
  assert.equal(verified.minutes, 45);
  assert.equal(verified.contentHash, hash);
  assert.equal(verified.durable, false);
  assert.equal(rootWrites, 1);
  assert.equal(calls.filter((method) => method === "ACK_WATCH_CONFIG_VERIFIED_V1").length >= 1, true);
  assert.equal(calls.includes("SUBMIT_WATCH_LOCK_V1"), false);

  const again = await receiveMatch({
    attempts: 3,
    wait: () => Promise.resolve(),
    loadInstallation: () => ({ ok: true, id: installation, reason: "" }),
    requestStore: requestStore,
    allocate: () => "88888888-8888-4888-8888-888888888888",
    admission: createWatchProvisionAdmission(store),
    request: (message) => {
      calls.push(message.method);
      if (message.method === "GET_WATCH_PROVISION_V1") return Promise.resolve(preparedBody());
      return Promise.resolve(verifiedBody(hash));
    },
  });
  assert.equal(again.result, "config-verified");
  assert.equal(again.requestId, requestId);
  assert.equal(rootWrites, 1);

  const conflict = await receiveMatch({
    attempts: 3,
    wait: () => Promise.resolve(),
    loadInstallation: () => ({ ok: true, id: installation, reason: "" }),
    requestStore: createMemoryTextStore(),
    allocate: () => "99999999-9999-4999-8999-999999999999",
    admission: createWatchProvisionAdmission(store),
    request: (message) => {
      if (message.method === "GET_WATCH_PROVISION_V1") return Promise.resolve(preparedBody());
      return Promise.resolve(verifiedBody("deadbeef"));
    },
  });
  assert.equal(conflict.result, "conflict");
  assert.equal(rootWrites, 1);
});
