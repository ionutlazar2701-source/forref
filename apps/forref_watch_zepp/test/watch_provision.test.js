import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { sha256Hex } from "../utils/sha256_hex.js";
import {
  createMemoryProvisionStore,
  createWatchProvisionAdmission,
  decidePhoneWatchProvision,
  parseWatchProvisionV1,
} from "../utils/watch_provision.js";

const fixture = JSON.parse(
  readFileSync(new URL("../../../packages/forref_match_core/test/fixtures/watch_provision_v1.json", import.meta.url), "utf8"),
);
const canonical = fixture.canonical;

test("sha256 matches the published abc vector", () => {
  assert.equal(sha256Hex("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
});

test("the canonical fixture parses and hashes the same bytes", () => {
  const parsed = parseWatchProvisionV1(canonical);
  assert.equal(parsed.document.canonical, canonical);
  assert.equal(parsed.document.contentHash, fixture.contentHash);
  assert.equal(sha256Hex(canonical), fixture.contentHash);
  assert.notEqual(parsed.document.homeTeamId, parsed.document.awayTeamId);
  assert.equal(parsed.document.homeTeamId === "HOME", false);
  assert.equal(parsed.document.awayTeamId === "AWAY", false);
});

test("missing, duplicated, and display-token ids are rejected", () => {
  assert.equal(parseWatchProvisionV1(canonical.replace("team-beta-001", "team-alpha-001")).reason, "teamId");
  assert.equal(parseWatchProvisionV1(canonical.replace("team-alpha-001", "HOME")).reason, "teamId");
  assert.equal(parseWatchProvisionV1(canonical.replace("team-beta-001", "AWAY")).reason, "teamId");
  assert.equal(parseWatchProvisionV1(canonical.slice(0, -1) + ',"extra":1}').reason, "schema");
  assert.equal(parseWatchProvisionV1(canonical.replace('"generation":1', '"generation":2')).reason, "generation");
});

test("a valid message becomes local match-ready only after readback", () => {
  const store = createMemoryProvisionStore();
  const result = createWatchProvisionAdmission(store).receive(canonical, fixture.localInstallationId, false);
  assert.deepEqual(result.trace, ["CONFIG_RECEIVED", "ROOT_VERIFIED", "MATCH_READY"]);
  assert.equal(result.saved, false);
  assert.equal(result.d1Certified, false);
  assert.equal(result.display, "LOCAL READBACK — D1 UNCERTIFIED");
  assert.equal(store.root, canonical);
});

test("an identical provision replays and a conflicting one is refused", () => {
  const store = createMemoryProvisionStore();
  const admission = createWatchProvisionAdmission(store);
  admission.receive(canonical, fixture.localInstallationId, false);
  const again = admission.receive(canonical, fixture.localInstallationId, false);
  assert.equal(again.state, "MATCH_READY");
  const conflict = admission.receive(canonical.replace("North", "East"), fixture.localInstallationId, false);
  assert.equal(conflict.state, "AUTHORITY_CONFLICT");
  assert.equal(conflict.reason, "reprovision");
  assert.equal(store.root, canonical);
});

test("the wrong installation identity writes nothing", () => {
  const store = createMemoryProvisionStore();
  const result = createWatchProvisionAdmission(store).receive(
    canonical,
    "00000000-0000-4000-8000-000000000001",
    false,
  );
  assert.equal(result.state, "AUTHORITY_CONFLICT");
  assert.equal(result.reason, "writerDeviceId");
  assert.equal(store.root, null);
});

test("sporting history with a missing root is not recreated", () => {
  const store = createMemoryProvisionStore();
  const result = createWatchProvisionAdmission(store).receive(canonical, fixture.localInstallationId, true);
  assert.equal(result.state, "RECOVERY_REQUIRED");
  assert.equal(result.reason, "missing-root");
  assert.equal(store.root, null);
});

test("a corrupt root is not replaced", () => {
  const store = createMemoryProvisionStore();
  store.root = "{";
  const result = createWatchProvisionAdmission(store).receive(canonical, fixture.localInstallationId, false);
  assert.equal(result.state, "RECOVERY_REQUIRED");
  assert.equal(result.reason, "corrupt-root");
  assert.equal(store.root, "{");
});

test("an interrupted root write is storage-unverified", () => {
  const store = createMemoryProvisionStore();
  store.failRootWrite = true;
  const result = createWatchProvisionAdmission(store).receive(canonical, fixture.localInstallationId, false);
  assert.equal(result.state, "STORAGE_UNVERIFIED");
  assert.equal(result.matchReady, false);
  assert.equal(store.root, null);
});

test("reopen reads the durable root after the first object is discarded", () => {
  const store = createMemoryProvisionStore();
  createWatchProvisionAdmission(store).receive(canonical, fixture.localInstallationId, false);
  const reopened = createWatchProvisionAdmission(store).loadDurable(false);
  assert.equal(reopened.state, "MATCH_READY");
  assert.equal(reopened.canonical, canonical);
  assert.equal(reopened.saved, false);
});

test("bluetooth loss after receipt keeps the stored configuration", () => {
  const store = createMemoryProvisionStore();
  createWatchProvisionAdmission(store).receive(canonical, fixture.localInstallationId, false);
  const offline = createWatchProvisionAdmission(store).loadDurable(false);
  assert.equal(offline.state, "MATCH_READY");
  assert.equal(offline.canonical, canonical);
});

test("the phone refuses its own writer and existing sporting history", () => {
  const asPhone = canonical.replace(fixture.localInstallationId, fixture.phoneOriginDeviceId);
  const self = decidePhoneWatchProvision(asPhone, {
    committedSportingRecords: 0,
    phoneOriginDeviceId: fixture.phoneOriginDeviceId,
  });
  assert.equal(self.reason, "phone-writer");
  assert.equal(self.rootToCommit, null);
  const history = decidePhoneWatchProvision(canonical, {
    committedSportingRecords: 2,
    phoneOriginDeviceId: fixture.phoneOriginDeviceId,
  });
  assert.equal(history.reason, "existing phone-authoritative history");
  assert.equal(history.matchReady, false);
  assert.equal(history.saved, false);
});

test("a clean phone preparation names the watch and writes no sporting payload", () => {
  const decision = decidePhoneWatchProvision(canonical, {
    committedSportingRecords: 0,
    phoneOriginDeviceId: fixture.phoneOriginDeviceId,
  });
  assert.equal(decision.reason, "phone-prepared");
  assert.equal(decision.matchReady, false);
  assert.equal(decision.rootToCommit.deviceId, fixture.localInstallationId);
  assert.equal(decision.rootToCommit.generation, 1);
  assert.equal(decision.canonical.includes("GOAL"), false);
});

test("the provision module does not touch the clock, home, or demo journal", () => {
  const source = readFileSync(new URL("../utils/watch_provision.js", import.meta.url), "utf8");
  assert.equal(source.includes("forref_clock"), false);
  assert.equal(source.includes("capture_candidate"), false);
  assert.equal(source.includes("SIM_"), false);
  assert.equal(source.includes("page/gt/home"), false);
});
