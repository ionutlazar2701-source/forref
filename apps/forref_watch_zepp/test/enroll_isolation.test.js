import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { place } from "../utils/geometry.js";
import { resolveInstallationCard } from "../utils/installation_label.js";
import {
  ENROLL_ADMISSION_FILE,
  ENROLL_CORRELATION_FILE,
  ENROLL_ROOT_FILE,
  PROVISION_CORRELATION_FILE,
  correlationText,
  loadCorrelation,
  runPrepare,
} from "../utils/provision_bridge.js";
import { createMemoryTextStore } from "../utils/provision_transport.js";
import { createMemoryProvisionStore, createWatchProvisionAdmission } from "../utils/watch_provision.js";

const fixture = JSON.parse(readFileSync(new URL("../../../packages/forref_match_core/test/fixtures/watch_provision_v1.json", import.meta.url), "utf8"));
const installationId = fixture.localInstallationId;
const historicalRequest = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee";
const enrollRequest = "44444444-4444-4444-8444-444444444444";

function preparedBody(requestId) {
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

test("enrollment prepare writes the enroll files and leaves the historical correlation", async () => {
  const historicalText = correlationText({
    installationId: installationId,
    requestId: historicalRequest,
    generation: 1,
    phase: "verified",
    matchId: "match-historical",
    contentHash: "ab".repeat(32),
  });
  const historical = createMemoryTextStore();
  historical.raw = historicalText;
  const historicalAdmission = createMemoryProvisionStore();
  historicalAdmission.root = "historical-root";
  historicalAdmission.admission = "historical-admission";
  const enroll = createMemoryTextStore();
  const enrollAdmission = createMemoryProvisionStore();
  let allocated = 0;
  const result = await runPrepare({
    loadInstallation: () => ({ ok: true, id: installationId, reason: "" }),
    requestStore: enroll,
    admission: createWatchProvisionAdmission(enrollAdmission),
    allocate: () => {
      allocated += 1;
      return enrollRequest;
    },
    request() {
      return Promise.resolve(preparedBody(enrollRequest));
    },
  });
  assert.equal(result.ok, true);
  assert.equal(result.requestId, enrollRequest);
  assert.equal(allocated, 1);
  assert.equal(historical.raw, historicalText);
  assert.equal(historicalAdmission.root, "historical-root");
  assert.equal(historicalAdmission.admission, "historical-admission");
  assert.equal(loadCorrelation(enroll, installationId).requestId, enrollRequest);
  assert.notEqual(enroll.raw, historical.raw);
  const again = await runPrepare({
    loadInstallation: () => ({ ok: true, id: installationId, reason: "" }),
    requestStore: enroll,
    admission: createWatchProvisionAdmission(enrollAdmission),
    allocate: () => {
      allocated += 1;
      return "55555555-5555-4555-8555-555555555555";
    },
    request() {
      return Promise.resolve(preparedBody(enrollRequest));
    },
  });
  assert.equal(again.ok, true);
  assert.equal(again.requestId, enrollRequest);
  assert.equal(allocated, 1);
  assert.equal(historical.raw, historicalText);
  assert.equal(historicalAdmission.root, "historical-root");
  assert.notEqual(ENROLL_CORRELATION_FILE, PROVISION_CORRELATION_FILE);
  assert.notEqual(ENROLL_ROOT_FILE, "forref_watch_provision_v1.root");
  assert.notEqual(ENROLL_ADMISSION_FILE, "forref_watch_provision_v1.admission");
});

test("the provision page keeps the historical button and adds an enroll control", () => {
  const page = readFileSync(new URL("../page/gt/provision/index.page.js", import.meta.url), "utf8");
  const bip6 = { width: 390, height: 450, round: false };
  const card = resolveInstallationCard(bip6);
  const enroll = place(bip6, card.back.y + card.back.h + 6, 40, card.back.w);
  assert.equal(card.ok, true);
  assert.equal(enroll.ok, true);
  assert.equal(page.includes('fileStore(PROVISION_CORRELATION_FILE)'), true);
  assert.equal(page.includes("ENROLL_CORRELATION_FILE"), true);
  assert.equal(page.includes("ENROLL_ROOT_FILE"), true);
  assert.equal(page.includes("ENROLL_ADMISSION_FILE"), true);
  assert.equal(page.includes('name: "provision-enroll"') || page.includes('"provision-enroll"'), true);
  assert.equal(page.includes("FORREF_ENROLL tx=preflight"), true);
  assert.equal(page.includes("historical-same="), true);
  assert.equal(page.includes("unlink"), false);
  assert.equal(page.includes("runHandshake"), false);
  assert.equal(page.includes("SUBMIT_WATCH_LOCK_V1"), false);
  assert.equal(page.indexOf("this.start()") < page.indexOf("this.enrollWitness()"), true);
});
