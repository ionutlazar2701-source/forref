import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createMemoryTextStore } from "../utils/provision_transport.js";
import {
  commitVerified,
  readMatchRegistry,
  transferRootName,
} from "../utils/match_registry.js";
import { receiveMatch } from "../utils/provision_bridge.js";
import {
  canonicalWatchProvisionV1,
  createMemoryProvisionStore,
  createWatchProvisionAdmission,
} from "../utils/watch_provision.js";
import { sha256Hex } from "../utils/sha256_hex.js";

const installation = "22222222-2222-4222-8222-222222222222";
const requestA = "44444444-4444-4444-8444-444444444444";
const requestB = "55555555-5555-4555-8555-555555555555";

function entry(name, matchId, hash) {
  return {
    matchId: matchId,
    homeTeamId: "team-" + name.toLowerCase() + "-home",
    homeName: name,
    awayTeamId: "team-" + name.toLowerCase() + "-away",
    awayName: name + " Away",
    halfDurationMs: 2700000,
    contentHash: hash,
    writerDeviceId: installation,
    generation: 1,
    status: "verified",
  };
}

function document(matchId, home, away) {
  return {
    matchId: matchId,
    principalId: "ref-1",
    writerDeviceId: installation,
    homeTeamId: "team-" + home.toLowerCase(),
    homeName: home,
    awayTeamId: "team-" + away.toLowerCase(),
    awayName: away,
    halfDurationMs: 2700000,
    provisionVersion: 1,
  };
}

test("a verified match is kept and a second match does not replace it", () => {
  const store = createMemoryTextStore();
  const hashA = "ab".repeat(32);
  const hashB = "cd".repeat(32);
  const first = commitVerified(store, entry("Alpha", "match-aaaa-1111", hashA));
  assert.equal(first.ok, true);
  assert.equal(first.wrote, true);
  const replay = commitVerified(store, entry("Alpha", "match-aaaa-1111", hashA));
  assert.equal(replay.ok, true);
  assert.equal(replay.wrote, false);
  assert.equal(replay.reason, "replay");
  const second = commitVerified(store, entry("Beta", "match-bbbb-2222", hashB));
  assert.equal(second.ok, true);
  assert.equal(second.matches.length, 2);
  const conflict = commitVerified(store, entry("Alpha", "match-aaaa-1111", hashB));
  assert.equal(conflict.ok, false);
  assert.equal(conflict.reason, "conflict");
  assert.equal(readMatchRegistry(store).matches.length, 2);
  assert.equal(readMatchRegistry(store).matches[0].homeName, "Alpha");
  const broken = createMemoryTextStore();
  broken.write("{");
  const kept = commitVerified(broken, entry("Alpha", "match-aaaa-1111", hashA));
  assert.equal(kept.ok, false);
  assert.equal(broken.read().text, "{");
  const failing = createMemoryTextStore();
  commitVerified(failing, entry("Alpha", "match-aaaa-1111", hashA));
  failing.write = () => ({ status: "unverified" });
  const stored = failing.read().text;
  const failed = commitVerified(failing, entry("Beta", "match-bbbb-2222", hashB));
  assert.equal(failed.reason, "registry-write");
  assert.equal(failing.read().text, stored);
  assert.equal(transferRootName("match-aaaa-1111"), "forref_watch_transfer_v1.match-aaaa-1111.root");
  assert.equal(transferRootName("../etc"), "");
});

test("successive receives keep separate roots and the registry", async () => {
  const registry = createMemoryTextStore();
  const roots = {};
  function admissionFor(matchId) {
    if (!roots[matchId]) {
      const store = createMemoryProvisionStore();
      store.writes = 0;
      const writeRoot = store.writeRoot.bind(store);
      store.writeRoot = (text) => {
        store.writes += 1;
        return writeRoot(text);
      };
      roots[matchId] = store;
    }
    return createWatchProvisionAdmission(roots[matchId]);
  }
  const requestStore = createMemoryTextStore();
  const ids = ["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", "cccccccc-cccc-4ccc-8ccc-cccccccccccc"];
  const names = ["Alpha", "Beta", "Gamma"];
  let fresh = 0;
  const freshIds = [requestA, requestB, "66666666-6666-4666-8666-666666666666"];
  for (let i = 0; i < ids.length; i += 1) {
    const doc = document(ids[i], names[i], "South");
    const canonical = canonicalWatchProvisionV1(doc);
    const hash = sha256Hex(canonical);
    const verified = await receiveMatch({
      attempts: 1,
      loadInstallation: () => ({ ok: true, id: installation, reason: "" }),
      requestStore: requestStore,
      allocate: () => freshIds[fresh += 1] || requestB,
      admissionFor: admissionFor,
      registry: registry,
      request: (message) => {
        if (message.method === "GET_WATCH_PROVISION_V1") {
          return Promise.resolve({
            disposition: "prepared",
            schema: "forref.watch-provision.v1",
            matchId: ids[i],
            contentHash: hash,
            installationId: installation,
            requestId: message.params.requestId,
            generation: 1,
            canonical: canonical,
            homeName: names[i],
            awayName: "South",
            saved: false,
            d1Certified: false,
          });
        }
        return Promise.resolve({
          disposition: "verified",
          reason: "",
          matchId: ids[i],
          contentHash: hash,
          installationId: installation,
          requestId: message.params.requestId,
          generation: 1,
          saved: false,
          durable: false,
          d1Certified: false,
        });
      },
    });
    assert.equal(verified.result, "config-verified");
    assert.equal(verified.homeName, names[i]);
    assert.equal(verified.durable, false);
    assert.equal(roots[ids[i]].writes, 1);
  }
  const listed = readMatchRegistry(registry);
  assert.equal(listed.ok, true);
  assert.equal(listed.matches.length, 3);
  assert.equal(roots[ids[0]].readRoot().text.includes("Alpha"), true);
  assert.equal(roots[ids[1]].readRoot().text.includes("Beta"), true);
  assert.equal(roots[ids[2]].readRoot().text.includes("Gamma"), true);
  const page = readFileSync(new URL("../page/gt/select/index.page.js", import.meta.url), "utf8");
  assert.equal(page.includes("readMatchRegistry"), true);
  assert.equal(page.includes("availableMatches"), true);
  assert.equal(page.includes("configVerified"), true);
  assert.equal(page.includes('t("fixture")'), false);
  assert.equal(page.includes("SUBMIT_WATCH_LOCK_V1"), false);
  assert.equal(page.includes("runHandshake"), false);
});
