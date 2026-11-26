import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { sha256Hex } from "../utils/sha256_hex.js";
import {
  LOCAL_RECORD_LABEL,
  canonicalWatchGoalV1,
  createGoalJournal,
  createMemoryGoalStore,
  parseGoalJournal,
} from "../utils/goal_journal.js";

const context = {
  matchId: "match-watch-001",
  principalId: "referee-001",
  writerDeviceId: "6f1e2d3c-4b5a-4678-9abc-def012345678",
  localInstallationId: "6f1e2d3c-4b5a-4678-9abc-def012345678",
  homeTeamId: "team-alpha-001",
  awayTeamId: "team-beta-001",
  authorityActivated: true,
  transportAvailable: false,
};

function journal(store, extra) {
  return createGoalJournal(store, Object.assign({}, context, extra || {}));
}

function goal(over) {
  return Object.assign({
    captureIntentId: "intent-home-1",
    recordId: "goal-home-1",
    scoringTeamId: "team-alpha-001",
    clockTrust: "TIME_UNVERIFIED",
  }, over || {});
}

test("the canonical goal envelope matches the Dart field meaning", () => {
  const canonical = canonicalWatchGoalV1({
    matchId: "match-watch-001",
    recordId: "goal-home-1",
    captureIntentId: "intent-home-1",
    scoringTeamId: "team-alpha-001",
    principalId: "referee-001",
    writerDeviceId: "6f1e2d3c-4b5a-4678-9abc-def012345678",
    originSequence: 1,
  });
  const fixture = JSON.parse(readFileSync(new URL("../../../packages/forref_match_core/test/fixtures/watch_goal_v1.json", import.meta.url), "utf8"));
  assert.equal(canonical, fixture.canonical);
  assert.equal(sha256Hex(canonical), fixture.contentHash);
  assert.equal(canonical.includes("HOME"), false);
  assert.equal(canonical.includes("TIME_UNVERIFIED"), false);
  assert.equal(canonical.includes("\"semanticType\":\"GOAL\""), true);
  assert.equal(canonical.includes("\"recordKind\":\"humanDetermination\""), true);
});

test("the first goal is a verified local record and not Saved", () => {
  const store = createMemoryGoalStore();
  const written = journal(store).append(goal());
  assert.equal(written.ok, true);
  assert.equal(written.label, LOCAL_RECORD_LABEL);
  assert.equal(written.saved, false);
  assert.equal(written.d1Certified, false);
  assert.equal(written.authoritativeCaptureAdmitted, false);
  assert.equal(written.entry.originSequence, 1);
  assert.equal(written.outcome === "DurableCommitSuccess", false);
});

test("the same intent replays and a different team is refused", () => {
  const store = createMemoryGoalStore();
  const book = journal(store);
  book.append(goal());
  const again = book.append(goal());
  assert.equal(again.reason, "idempotent");
  assert.equal(again.entries.length, 1);
  const otherTeam = book.append(goal({ scoringTeamId: "team-beta-001" }));
  assert.equal(otherTeam.reason, "intent-conflict");
  assert.equal(store.raw.includes("team-beta-001"), false);
});

test("two deliberate goals for one team both remain", () => {
  const store = createMemoryGoalStore();
  const book = journal(store);
  assert.equal(book.append(goal()).ok, true);
  const second = book.append(goal({ captureIntentId: "intent-home-2", recordId: "goal-home-2" }));
  assert.equal(second.ok, true);
  assert.equal(second.entries.length, 2);
  assert.equal(second.entry.originSequence, 2);
});

test("a crash after the append is recovered without a second goal", () => {
  const store = createMemoryGoalStore();
  const first = journal(store);
  const written = first.append(goal());
  assert.equal(written.ok, true);
  const reopened = journal(store);
  const recovered = reopened.append(goal());
  assert.equal(recovered.reason, "idempotent");
  assert.equal(recovered.entries.length, 1);
  assert.equal(recovered.entry.recordId, "goal-home-1");
});

test("an uncertain write keeps the intent and retries the same record", () => {
  const store = createMemoryGoalStore();
  store.failWrite = true;
  const book = journal(store);
  const uncertain = book.append(goal());
  assert.equal(uncertain.uncertain, true);
  assert.equal(uncertain.captureIntentId, "intent-home-1");
  assert.equal(uncertain.saved, false);
  const blocked = book.append(goal({ captureIntentId: "intent-other", recordId: "goal-other" }));
  assert.equal(blocked.reason, "reconciliation");
  store.failWrite = false;
  const retried = book.append(goal());
  assert.equal(retried.ok, true);
  assert.equal(retried.entries.length, 1);
});

test("a short write is preserved and blocks another append", () => {
  const store = createMemoryGoalStore();
  store.shortWrite = true;
  const book = journal(store);
  const torn = book.append(goal());
  assert.equal(torn.uncertain, true);
  assert.equal(torn.reason === "short-write" || torn.reason === "torn-tail" || torn.reason === "read-after-write", true);
  const preserved = store.raw;
  store.shortWrite = false;
  const blocked = book.append(goal({ captureIntentId: "intent-home-2", recordId: "goal-home-2" }));
  assert.equal(blocked.ok, false);
  assert.equal(blocked.uncertain, true);
  assert.equal(store.raw, preserved);
});

test("a read failure after a durable-looking write stays uncertain", () => {
  const store = createMemoryGoalStore();
  const original = store.write.bind(store);
  store.write = function (text) {
    const wrote = original(text);
    this.unreadable = true;
    return wrote;
  };
  const uncertain = journal(store).append(goal());
  assert.equal(uncertain.uncertain, true);
  assert.equal(uncertain.ok, false);
  assert.equal(uncertain.captureIntentId, "intent-home-1");
});

test("duplicate origin slots and conflicting record ids fail closed", () => {
  const entry = {
    matchId: context.matchId,
    recordId: "goal-home-1",
    captureIntentId: "intent-home-1",
    scoringTeamId: "team-alpha-001",
    principalId: context.principalId,
    writerDeviceId: context.writerDeviceId,
    originSequence: 1,
  };
  const body = canonicalWatchGoalV1(entry);
  const frame = "F1 1 " + Buffer.byteLength(body) + " " + sha256Hex(body) + "\n" + body + "\n.\n";
  const duplicate = parseGoalJournal(frame + frame.replace("F1 1 ", "F1 1 "));
  assert.equal(duplicate.status, "corrupt");
  const other = canonicalWatchGoalV1(Object.assign({}, entry, {
    captureIntentId: "intent-home-2",
    originSequence: 2,
  }));
  const second = "F1 2 " + Buffer.byteLength(other) + " " + sha256Hex(other) + "\n" + other + "\n.\n";
  const conflict = parseGoalJournal(frame + second);
  assert.equal(conflict.reason, "record-id");
  const store = createMemoryGoalStore();
  store.raw = frame + second;
  const refused = journal(store).append(goal({ captureIntentId: "intent-home-3", recordId: "goal-home-3" }));
  assert.equal(refused.ok, false);
  assert.equal(store.raw, frame + second);
});

test("the wrong installation and a missing installation fail closed", () => {
  const store = createMemoryGoalStore();
  journal(store).append(goal());
  const preserved = store.raw;
  const wrong = journal(store, { localInstallationId: "00000000-0000-4000-8000-000000000099" }).append(goal({
    captureIntentId: "intent-home-2",
    recordId: "goal-home-2",
  }));
  assert.equal(wrong.reason, "installation-identity");
  assert.equal(store.raw, preserved);
  const missing = journal(store, { localInstallationId: "" }).append(goal({
    captureIntentId: "intent-home-2",
    recordId: "goal-home-2",
  }));
  assert.equal(missing.reason, "missing-installation");
  assert.equal(store.raw, preserved);
});

test("local capture does not consult transport or invent a match minute", () => {
  const store = createMemoryGoalStore();
  const written = journal(store, { transportAvailable: false, authorityActivated: true }).append(goal());
  assert.equal(written.ok, true);
  assert.equal(store.raw.includes("TIME_UNVERIFIED"), false);
  assert.equal(store.raw.includes("Bluetooth"), false);
  const inactive = journal(createMemoryGoalStore(), { authorityActivated: false }).append(goal());
  assert.equal(inactive.reason, "authority-not-activated");
});

test("one hundred goals stay ordered and the next one stops at capacity", () => {
  const store = createMemoryGoalStore();
  const book = journal(store, { maxEntries: 100 });
  for (let i = 1; i <= 100; i += 1) {
    const written = book.append(goal({
      captureIntentId: "intent-" + i,
      recordId: "goal-" + i,
      scoringTeamId: i % 2 === 0 ? "team-beta-001" : "team-alpha-001",
    }));
    assert.equal(written.ok, true, String(i));
    assert.equal(written.entry.originSequence, i);
  }
  const full = book.append(goal({ captureIntentId: "intent-101", recordId: "goal-101" }));
  assert.equal(full.reason, "capacity");
  assert.equal(full.entries.length, 100);
  const reopened = journal(store, { maxEntries: 100 }).load();
  assert.equal(reopened.entries.length, 100);
  assert.equal(reopened.entries[99].originSequence, 100);
});

test("the goal journal does not touch the clock, demo journal, or theme", () => {
  const source = readFileSync(new URL("../utils/goal_journal.js", import.meta.url), "utf8");
  assert.equal(source.includes("forref_clock"), false);
  assert.equal(source.includes("capture_candidate"), false);
  assert.equal(source.includes("forref_capture_bridge_001"), false);
  assert.equal(source.includes("utils/theme"), false);
  assert.equal(source.includes("SIM_"), false);
});
