import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { PROVISION_ADMISSION_FILE, PROVISION_ROOT_FILE } from "../utils/goal_admission.js";
import { INSTALLATION_FILE } from "../utils/installation_id.js";
import { durablePath, resolveInstallation } from "../utils/installation_continuity.js";
import { ENROLL_CORRELATION_FILE, PROVISION_CORRELATION_FILE } from "../utils/provision_bridge.js";
import { stageMarker } from "../utils/watch_provision.js";

const kept = "166e7c3b-1111-4222-8333-000000000e43";
const other = "03e0d543-1111-4222-8333-000000000a51";
const source = readFileSync(new URL("../utils/installation_continuity.js", import.meta.url), "utf8");
const page = readFileSync(new URL("../page/gt/provision/index.page.js", import.meta.url), "utf8");

function memoryFs(initial) {
  const files = Object.assign({}, initial);
  return {
    files: files,
    writes: [],
    readFileSync(request) {
      if (!Object.prototype.hasOwnProperty.call(files, request.path)) throw new Error("ENOENT: not found");
      return files[request.path];
    },
    writeFileSync(request) {
      this.writes.push(request.path);
      files[request.path] = request.data;
    },
    readdirSync() {
      return Object.keys(files);
    },
  };
}

test("a relaunch reuses the data directory uuid and does not mint another", () => {
  const fs = memoryFs({ [durablePath(INSTALLATION_FILE)]: kept });
  const first = resolveInstallation(fs);
  const second = resolveInstallation(fs);
  assert.equal(first.ok, true);
  assert.equal(first.created, false);
  assert.equal(first.case, "reused");
  assert.equal(first.evidence, "data");
  assert.equal(second.id, kept);
  assert.equal(second.created, false);
  assert.equal(fs.writes.length, 0);
  assert.equal(fs.files[durablePath(INSTALLATION_FILE)], kept);
});

test("an in-place upgrade keeps the legacy uuid and copies it into data", () => {
  const correlation = '{"installationId":"' + kept + '","requestId":"11111111-2222-4333-8444-555555555555","generation":1,"phase":"verified","matchId":"match-1","contentHash":"' + "ab".repeat(32) + '"}';
  const fs = memoryFs({
    [INSTALLATION_FILE]: kept,
    [PROVISION_CORRELATION_FILE]: correlation,
    [PROVISION_ROOT_FILE]: "root-bytes",
  });
  const result = resolveInstallation(fs);
  assert.equal(result.ok, true);
  assert.equal(result.created, false);
  assert.equal(result.id, kept);
  assert.equal(result.evidence, "legacy");
  assert.equal(fs.files[INSTALLATION_FILE], kept);
  assert.equal(fs.files[durablePath(INSTALLATION_FILE)], kept);
  assert.equal(fs.files[durablePath(PROVISION_CORRELATION_FILE)], correlation);
  assert.equal(fs.files[PROVISION_CORRELATION_FILE], correlation);
  assert.equal(fs.files[durablePath(PROVISION_ROOT_FILE)], "root-bytes");
  assert.equal(result.phase, "verified");
  assert.equal(result.line.includes(kept), true);
  assert.equal(result.line.includes("created=0"), true);
});

test("a missing uuid with prepared or activated state does not create a writer", () => {
  const prepared = memoryFs({ [PROVISION_ROOT_FILE]: "root-bytes" });
  const preparedResult = resolveInstallation(prepared);
  assert.equal(preparedResult.ok, false);
  assert.equal(preparedResult.reason, "lost-identity-prepared");
  assert.equal(preparedResult.created, false);
  assert.equal(prepared.writes.length, 0);
  const activated = memoryFs({
    [PROVISION_ADMISSION_FILE]: stageMarker("ab".repeat(32), "WATCH_ACTIVATED"),
  });
  const activatedResult = resolveInstallation(activated);
  assert.equal(activatedResult.ok, false);
  assert.equal(activatedResult.reason, "lost-identity-activated");
  assert.equal(activated.writes.length, 0);
  const journal = memoryFs({});
  journal.readdirSync = () => ["forref_watch_goal_journal_v2." + "cd".repeat(32) + ".journal"];
  const journalResult = resolveInstallation(journal);
  assert.equal(journalResult.ok, false);
  assert.equal(journalResult.reason, "lost-identity-state");
  assert.equal(journal.writes.length, 0);
});

test("conflicting or unreadable identity is kept and a fresh store can create one uuid", () => {
  const conflict = memoryFs({
    [INSTALLATION_FILE]: kept,
    [durablePath(INSTALLATION_FILE)]: other,
  });
  const conflicted = resolveInstallation(conflict);
  assert.equal(conflicted.ok, false);
  assert.equal(conflicted.reason, "identity-conflict");
  assert.equal(conflict.files[INSTALLATION_FILE], kept);
  assert.equal(conflict.files[durablePath(INSTALLATION_FILE)], other);
  assert.equal(conflict.writes.length, 0);
  const torn = memoryFs({ [INSTALLATION_FILE]: "not-a-uuid" });
  assert.equal(resolveInstallation(torn).reason, "corrupt");
  assert.equal(torn.writes.length, 0);
  const clockOnly = memoryFs({ "forref_clock001c_state.json": "{\"demo\":true}" });
  const fresh = resolveInstallation(clockOnly);
  const again = resolveInstallation(clockOnly);
  assert.equal(fresh.ok, true);
  assert.equal(fresh.created, true);
  assert.equal(fresh.case, "fresh");
  assert.equal(fresh.id, again.id);
  assert.equal(clockOnly.files[durablePath(INSTALLATION_FILE)], fresh.id);
  assert.equal(Object.prototype.hasOwnProperty.call(clockOnly.files, INSTALLATION_FILE), false);
  assert.equal(source.includes("BUILD_"), false);
  assert.equal(source.includes("unlink"), false);
  assert.equal(source.includes("47221"), false);
  assert.equal(page.includes("runHandshake"), false);
  assert.equal(page.includes("resolveInstallation"), true);
  assert.equal(page.indexOf("if (!kept)") < page.indexOf("runPrepare({"), true);
});

test("an enroll file blocks a new installation uuid and is not copied onto the historical names", () => {
  const enrollText = '{"installationId":"' + kept + '","requestId":"44444444-4444-4444-8444-444444444444","generation":1,"phase":"pending"}';
  const enrolled = memoryFs({ [ENROLL_CORRELATION_FILE]: enrollText });
  const blocked = resolveInstallation(enrolled);
  assert.equal(blocked.ok, false);
  assert.equal(blocked.reason, "lost-identity-state");
  assert.equal(blocked.created, false);
  assert.equal(blocked.line.includes("enroll=present"), true);
  assert.equal(enrolled.writes.length, 0);
  assert.equal(enrolled.files[ENROLL_CORRELATION_FILE], enrollText);
  assert.equal(Object.prototype.hasOwnProperty.call(enrolled.files, durablePath(INSTALLATION_FILE)), false);
  assert.equal(Object.prototype.hasOwnProperty.call(enrolled.files, PROVISION_CORRELATION_FILE), false);
  const known = memoryFs({
    [durablePath(INSTALLATION_FILE)]: kept,
    [ENROLL_CORRELATION_FILE]: enrollText,
  });
  const reused = resolveInstallation(known);
  assert.equal(reused.ok, true);
  assert.equal(reused.created, false);
  assert.equal(reused.id, kept);
  assert.equal(known.writes.length, 0);
  assert.equal(known.files[ENROLL_CORRELATION_FILE], enrollText);
  assert.equal(Object.prototype.hasOwnProperty.call(known.files, PROVISION_CORRELATION_FILE), false);
  assert.equal(source.includes(ENROLL_CORRELATION_FILE), true);
  assert.equal(source.includes("copyLegacy(fs, ENROLL_"), false);
});
