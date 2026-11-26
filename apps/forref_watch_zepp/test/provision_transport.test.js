import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { loadInstallationId } from "../utils/installation_id.js";
import {
  ACTIVATE_WATCH_V1,
  GET_WATCH_PROVISION_V1,
  WATCH_ACTIVATED_V1,
  WATCH_PROVISION_VERIFIED_V1,
  createFileProvisionStore,
  createMemoryTextStore,
  createWatchProvisionAdmission,
  handleProvisionMessage,
} from "../utils/provision_transport.js";
import { createMemoryProvisionStore } from "../utils/watch_provision.js";

const fixture = JSON.parse(
  readFileSync(new URL("../../../packages/forref_match_core/test/fixtures/watch_provision_v1.json", import.meta.url), "utf8"),
);

test("the installation id is created once and a failed read does not replace it", () => {
  const store = createMemoryTextStore();
  const created = loadInstallationId(store);
  assert.equal(created.ok, true);
  const again = loadInstallationId(store);
  assert.equal(again.id, created.id);
  store.failRead = true;
  const failed = loadInstallationId(store);
  assert.equal(failed.ok, false);
  assert.equal(failed.reason, "unreadable");
  store.failRead = false;
  assert.equal(loadInstallationId(store).id, created.id);
});

test("verification readback is required before activation and a lost ack retries once", () => {
  const store = createMemoryProvisionStore();
  const admission = createWatchProvisionAdmission(store);
  const context = createMemoryTextStore();
  const verified = handleProvisionMessage({
    type: GET_WATCH_PROVISION_V1,
    matchId: "match-watch-001",
    contentHash: fixture.contentHash,
    canonical: fixture.canonical,
  }, admission, fixture.localInstallationId, context);
  assert.equal(verified.type, WATCH_PROVISION_VERIFIED_V1);
  assert.equal(verified.readBack, true);
  assert.equal(verified.writerDeviceId, fixture.localInstallationId);
  assert.equal(context.raw, null);
  const lost = handleProvisionMessage({
    type: ACTIVATE_WATCH_V1,
    matchId: "match-watch-001",
    contentHash: fixture.contentHash,
    lockReceipt: {
      contentHash: fixture.contentHash,
      writerDeviceId: fixture.localInstallationId,
      generation: 1,
      durable: false,
    },
  }, admission, fixture.localInstallationId, context);
  assert.equal(lost.type, "REFUSED");
  assert.equal(context.raw, null);
  const activated = handleProvisionMessage({
    type: ACTIVATE_WATCH_V1,
    matchId: "match-watch-001",
    contentHash: fixture.contentHash,
    lockReceipt: {
      contentHash: fixture.contentHash,
      writerDeviceId: fixture.localInstallationId,
      generation: 1,
      durable: true,
    },
  }, admission, fixture.localInstallationId, context);
  assert.equal(activated.type, WATCH_ACTIVATED_V1);
  assert.equal(JSON.parse(context.raw).authorityActivated, true);
  assert.equal(JSON.parse(context.raw).homeTeamId, "team-alpha-001");
  const again = handleProvisionMessage({
    type: ACTIVATE_WATCH_V1,
    matchId: "match-watch-001",
    contentHash: fixture.contentHash,
    lockReceipt: {
      contentHash: fixture.contentHash,
      writerDeviceId: fixture.localInstallationId,
      generation: 1,
      durable: true,
    },
  }, admission, fixture.localInstallationId, context);
  assert.equal(again.type, WATCH_ACTIVATED_V1);
  assert.equal(store.admission.includes("WATCH_ACTIVATED"), true);
});

test("a conflicting activation and a write without readback are refused", () => {
  const store = createMemoryProvisionStore();
  const admission = createWatchProvisionAdmission(store);
  handleProvisionMessage({
    type: GET_WATCH_PROVISION_V1,
    matchId: "match-watch-001",
    contentHash: fixture.contentHash,
    canonical: fixture.canonical,
  }, admission, fixture.localInstallationId, null);
  const conflict = handleProvisionMessage({
    type: ACTIVATE_WATCH_V1,
    matchId: "match-watch-001",
    contentHash: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    lockReceipt: {
      contentHash: fixture.contentHash,
      writerDeviceId: fixture.localInstallationId,
      generation: 1,
      durable: true,
    },
  }, admission, fixture.localInstallationId, createMemoryTextStore());
  assert.equal(conflict.reason, "conflicting-activation");
  const files = {};
  const fs = {
    readFileSync(request) {
      if (!Object.prototype.hasOwnProperty.call(files, request.path)) {
        const error = new Error("ENOENT");
        throw error;
      }
      return files[request.path];
    },
    writeFileSync(request) {
      files[request.path] = request.data.slice(0, request.data.length - 4);
    },
  };
  const adapted = createFileProvisionStore(fs, "root", "marker");
  const wrote = adapted.writeRoot(fixture.canonical);
  assert.equal(wrote.status, "unverified");
});
