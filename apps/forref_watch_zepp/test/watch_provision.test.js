import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { sha256Hex } from "../utils/sha256_hex.js";
import {
  createMemoryProvisionStore,
  createWatchProvisionAdmission,
  decidePhoneAuthorityLock,
  decidePhoneWatchProvision,
  parseWatchProvisionV1,
  stageMarker,
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

test("a valid message stops at verified configuration", () => {
  const store = createMemoryProvisionStore();
  const result = createWatchProvisionAdmission(store).receive(canonical, fixture.localInstallationId, false);
  assert.equal(result.state, "WATCH_CONFIG_VERIFIED");
  assert.equal(result.saved, false);
  assert.equal(result.d1Certified, false);
  assert.equal(result.mayAppendSportingRecords, false);
  assert.equal(result.display, "CONFIG VERIFIED — NOT ACTIVATED");
  assert.equal(store.root, canonical);
});

test("an identical provision replays and a conflicting one is refused", () => {
  const store = createMemoryProvisionStore();
  const admission = createWatchProvisionAdmission(store);
  admission.receive(canonical, fixture.localInstallationId, false);
  const again = admission.receive(canonical, fixture.localInstallationId, false);
  assert.equal(again.state, "WATCH_CONFIG_VERIFIED");
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
  assert.equal(result.mayAppendSportingRecords, false);
  assert.equal(store.root, null);
});

test("reopen reads the durable root after the first object is discarded", () => {
  const store = createMemoryProvisionStore();
  createWatchProvisionAdmission(store).receive(canonical, fixture.localInstallationId, false);
  const reopened = createWatchProvisionAdmission(store).loadDurable(fixture.localInstallationId, false);
  assert.equal(reopened.state, "WATCH_CONFIG_VERIFIED");
  assert.equal(reopened.canonical, canonical);
  assert.equal(reopened.saved, false);
});

test("bluetooth loss after receipt keeps the stored configuration", () => {
  const store = createMemoryProvisionStore();
  createWatchProvisionAdmission(store).receive(canonical, fixture.localInstallationId, false);
  const offline = createWatchProvisionAdmission(store).loadDurable(fixture.localInstallationId, false);
  assert.equal(offline.state, "WATCH_CONFIG_VERIFIED");
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
  assert.equal(history.mayAppendSportingRecords, false);
  assert.equal(history.saved, false);
});

test("a clean phone preparation names the watch and writes no sporting payload", () => {
  const decision = decidePhoneWatchProvision(canonical, {
    committedSportingRecords: 0,
    phoneOriginDeviceId: fixture.phoneOriginDeviceId,
  });
  assert.equal(decision.reason, "phone-prepared");
  assert.equal(decision.state, "CONFIG_PREPARED");
  assert.equal(decision.mayAppendSportingRecords, false);
  assert.equal(decision.rootToCommit, null);
  assert.equal(decision.canonical.includes("GOAL"), false);
});

test("transport unavailable leaves the phone prepared and unlocked", () => {
  const locked = decidePhoneAuthorityLock(canonical, {
    committedSportingRecords: 0,
    phoneOriginDeviceId: fixture.phoneOriginDeviceId,
  }, null, false);
  assert.equal(locked.state, "CONFIG_PREPARED");
  assert.equal(locked.reason, "transport-unavailable");
  assert.equal(locked.rootToCommit, null);
});

test("an existing root does not make an invalid receipt durable", () => {
  const facts = {
    committedSportingRecords: 0,
    phoneOriginDeviceId: fixture.phoneOriginDeviceId,
    rootDeviceId: fixture.localInstallationId,
    rootPrincipalId: "referee-001",
  };
  const invalid = decidePhoneAuthorityLock(canonical, facts, {
    contentHash: fixture.contentHash,
    writerDeviceId: fixture.localInstallationId,
    generation: 1,
    readBack: false,
  }, true);
  assert.equal(invalid.state, "CONFIG_PREPARED");
  assert.equal(invalid.reason, "receipt-invalid");
  assert.equal(invalid.rootToCommit, null);
  const repeated = decidePhoneAuthorityLock(canonical, facts, {
    contentHash: fixture.contentHash,
    writerDeviceId: fixture.localInstallationId,
    generation: 1,
    readBack: true,
  }, true);
  assert.equal(repeated.state, "PHONE_AUTHORITY_LOCKED");
  assert.equal(repeated.reason, "idempotent-lock");
  assert.equal(repeated.rootToCommit, null);
});

test("activation never arrives so the watch cannot append", () => {
  const store = createMemoryProvisionStore();
  const admission = createWatchProvisionAdmission(store);
  admission.receive(canonical, fixture.localInstallationId, false);
  const waiting = admission.activate(fixture.localInstallationId, null);
  assert.equal(waiting.state, "WATCH_CONFIG_VERIFIED");
  assert.equal(waiting.reason, "activation-ack");
  assert.equal(waiting.mayAppendSportingRecords, false);
});

test("a lost activation acknowledgement retries once", () => {
  const store = createMemoryProvisionStore();
  const admission = createWatchProvisionAdmission(store);
  admission.receive(canonical, fixture.localInstallationId, false);
  const lost = admission.activate(fixture.localInstallationId, {
    contentHash: fixture.contentHash,
    writerDeviceId: fixture.localInstallationId,
    generation: 1,
    durable: false,
  });
  assert.equal(lost.state, "WATCH_CONFIG_VERIFIED");
  const activated = admission.activate(fixture.localInstallationId, {
    contentHash: fixture.contentHash,
    writerDeviceId: fixture.localInstallationId,
    generation: 1,
    durable: true,
  });
  assert.equal(activated.state, "WATCH_ACTIVATED");
  assert.equal(activated.authorityActivated, true);
  assert.equal(activated.captureStorageCertified, false);
  assert.equal(activated.authoritativeCaptureAdmitted, false);
  assert.equal(activated.mayAppendSportingRecords, false);
  assert.equal(activated.saved, false);
  const again = admission.activate(fixture.localInstallationId, {
    contentHash: fixture.contentHash,
    writerDeviceId: fixture.localInstallationId,
    generation: 1,
    durable: true,
  });
  assert.equal(again.state, "WATCH_ACTIVATED");
  assert.equal(store.admission, stageMarker(fixture.contentHash, "WATCH_ACTIVATED"));
});

test("restart before activation stays verified and after stays activated", () => {
  const store = createMemoryProvisionStore();
  createWatchProvisionAdmission(store).receive(canonical, fixture.localInstallationId, false);
  const before = createWatchProvisionAdmission(store).loadDurable(fixture.localInstallationId, false);
  assert.equal(before.state, "WATCH_CONFIG_VERIFIED");
  createWatchProvisionAdmission(store).activate(fixture.localInstallationId, {
    contentHash: fixture.contentHash,
    writerDeviceId: fixture.localInstallationId,
    generation: 1,
    durable: true,
  });
  const after = createWatchProvisionAdmission(store).loadDurable(fixture.localInstallationId, false);
  assert.equal(after.state, "WATCH_ACTIVATED");
  assert.equal(after.authorityActivated, true);
  assert.equal(after.authoritativeCaptureAdmitted, false);
});

test("a changed installation identity fails closed and keeps the root", () => {
  const store = createMemoryProvisionStore();
  createWatchProvisionAdmission(store).receive(canonical, fixture.localInstallationId, false);
  const changed = createWatchProvisionAdmission(store).loadDurable("00000000-0000-4000-8000-000000000099", false);
  assert.equal(changed.state, "AUTHORITY_CONFLICT");
  assert.equal(changed.reason, "installation-identity");
  assert.equal(store.root, canonical);
});

test("a conflicting activation is refused", () => {
  const store = createMemoryProvisionStore();
  const admission = createWatchProvisionAdmission(store);
  admission.receive(canonical, fixture.localInstallationId, false);
  const conflict = admission.activate(fixture.localInstallationId, {
    contentHash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    writerDeviceId: fixture.localInstallationId,
    generation: 1,
    durable: true,
  });
  assert.equal(conflict.state, "AUTHORITY_CONFLICT");
  assert.equal(conflict.reason, "conflicting-activation");
  assert.equal(store.admission.includes("WATCH_CONFIG_VERIFIED"), true);
});

test("the provision module does not touch the clock, home, or demo journal", () => {
  const source = readFileSync(new URL("../utils/watch_provision.js", import.meta.url), "utf8");
  assert.equal(source.includes("forref_clock"), false);
  assert.equal(source.includes("capture_candidate"), false);
  assert.equal(source.includes("SIM_"), false);
  assert.equal(source.includes("page/gt/home"), false);
});
