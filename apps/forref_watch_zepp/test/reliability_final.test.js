import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { sha256Hex } from "../utils/sha256_hex.js";
import {
  GOAL_JOURNAL_LEGACY_FILE,
  canonicalManifest,
  canonicalWatchGoalV1,
  createFileGoalStore,
  createGoalJournal,
  createMemoryGoalStore,
  goalFrameHash,
  goalJournalNameV2,
  recoverGoalHistory,
  selectGoalJournalPath,
} from "../utils/goal_journal.js";
import { INSTALLATION_FILE } from "../utils/installation_id.js";
import { PROVISION_ADMISSION_FILE, PROVISION_ROOT_FILE } from "../utils/goal_admission.js";
import { canonicalPending, createMemoryPendingStore, openLocalGoal } from "../utils/goal_capture.js";
import { stageMarker } from "../utils/watch_provision.js";

const context = {
  matchId: "match-watch-001",
  principalId: "referee-001",
  writerDeviceId: "6f1e2d3c-4b5a-4678-9abc-def012345678",
  localInstallationId: "6f1e2d3c-4b5a-4678-9abc-def012345678",
  homeTeamId: "team-alpha-001",
  awayTeamId: "team-beta-001",
  authorityActivated: true,
  generation: 1,
};

const fixture = JSON.parse(readFileSync(new URL("../../../packages/forref_match_core/test/fixtures/watch_provision_v1.json", import.meta.url), "utf8"));

function frame(entry) {
  const body = canonicalWatchGoalV1(entry);
  return "F1 " + entry.originSequence + " " + Buffer.byteLength(body) + " " + sha256Hex(body) + "\n" + body + "\n.\n";
}

function entry(over) {
  return Object.assign({
    matchId: context.matchId,
    recordId: "goal-home-1",
    captureIntentId: "intent-home-1",
    scoringTeamId: "team-alpha-001",
    principalId: context.principalId,
    writerDeviceId: context.writerDeviceId,
    originSequence: 1,
  }, over || {});
}

function mapFs(files, extra) {
  const fds = {};
  let nextFd = 3;
  const fs = {
    O_WRONLY: 1,
    O_CREAT: 0x0200,
    O_APPEND: 0x0008,
    opened: [],
    readFileSync(request) {
      if (!Object.prototype.hasOwnProperty.call(files, request.path)) throw new Error("ENOENT: not found");
      return files[request.path];
    },
    writeFileSync(request) {
      files[request.path] = request.data;
    },
    openSync(request) {
      fs.opened.push(request.path);
      const fd = nextFd;
      nextFd += 1;
      fds[fd] = request.path;
      return fd;
    },
    writeSync(request) {
      const bytes = new Uint8Array(request.buffer);
      let text = "";
      for (let i = 0; i < request.options.length; i += 1) text += String.fromCharCode(bytes[i]);
      const path = fds[request.fd];
      files[path] = (files[path] || "") + text;
      return request.options.length;
    },
    closeSync() {
      return 0;
    },
  };
  return Object.assign(fs, extra || {});
}

test("a corrupt legacy journal is not replaced by an empty match journal", () => {
  const files = { [GOAL_JOURNAL_LEGACY_FILE]: "NOT-A-JOURNAL" };
  const before = files[GOAL_JOURNAL_LEGACY_FILE];
  const selected = selectGoalJournalPath(mapFs(files), context.matchId);
  assert.equal(selected.ok, false);
  assert.equal(selected.reason, "journal-corrupt");
  assert.equal(selected.path, "");
  assert.equal(files[GOAL_JOURNAL_LEGACY_FILE], before);
  assert.equal(Object.keys(files).length, 1);
});

test("a torn legacy tail blocks selection and keeps the accepted prefix", () => {
  const first = frame(entry());
  const second = frame(entry({ captureIntentId: "intent-home-2", recordId: "goal-home-2", originSequence: 2 }));
  const files = { [GOAL_JOURNAL_LEGACY_FILE]: first + second + "F1 3 4 abcd\n" };
  const before = files[GOAL_JOURNAL_LEGACY_FILE];
  const selected = selectGoalJournalPath(mapFs(files), context.matchId);
  assert.equal(selected.ok, false);
  assert.equal(selected.reason, "journal-torn");
  assert.equal(files[GOAL_JOURNAL_LEGACY_FILE], before);
});

test("two journals for one match are refused", () => {
  const body = frame(entry());
  const files = {};
  files[GOAL_JOURNAL_LEGACY_FILE] = body;
  files[goalJournalNameV2(context.matchId)] = body;
  const selected = selectGoalJournalPath(mapFs(files), context.matchId);
  assert.equal(selected.ok, false);
  assert.equal(selected.reason, "ambiguous-journal");
  assert.equal(files[GOAL_JOURNAL_LEGACY_FILE], body);
  assert.equal(files[goalJournalNameV2(context.matchId)], body);
});

test("v2 filenames hash the exact match id", () => {
  const ids = ["mățch", "home team", "a/b", "a\\b", "x".repeat(128)];
  for (let i = 0; i < ids.length; i += 1) {
    const name = goalJournalNameV2(ids[i]);
    assert.match(name, /^forref_watch_goal_journal_v2\.[0-9a-f]{64}\.journal$/);
    assert.equal(name, "forref_watch_goal_journal_v2." + sha256Hex(ids[i]) + ".journal");
    assert.equal(name.includes(ids[i]), false);
  }
  assert.equal(
    goalJournalNameV2("mățch"),
    "forref_watch_goal_journal_v2.f088f7e75f4b2eb5ad3179eb7d82ca18f23d731092e2149b9071da7a154811bd.journal",
  );
  assert.equal(
    goalJournalNameV2("home team"),
    "forref_watch_goal_journal_v2.8ecabaa201d7ef377839350ed3e66404ca87d80a9f52529faa8cce59e56d4600.journal",
  );
  assert.equal(
    goalJournalNameV2("a/b"),
    "forref_watch_goal_journal_v2.c14cddc033f64b9dea80ea675cf280a015e672516090a5626781153dc68fea11.journal",
  );
  assert.equal(goalJournalNameV2("x".repeat(129)), "");
  const selected = selectGoalJournalPath(mapFs({}), "home team");
  assert.equal(selected.ok, true);
  assert.equal(selected.path, goalJournalNameV2("home team"));
});

test("a nonzero close leaves the intent uncertain and the next read reuses the frame", () => {
  const files = {};
  let closes = 0;
  const fs = mapFs(files, {
    closeSync() {
      closes += 1;
      return closes === 1 ? 2 : 0;
    },
  });
  const book = createGoalJournal(createFileGoalStore(fs, "journal"), context);
  const first = book.append({ captureIntentId: "intent-home-1", recordId: "goal-home-1", scoringTeamId: "team-alpha-001" });
  assert.equal(first.ok, false);
  assert.equal(first.uncertain, true);
  assert.equal(first.reason, "close");
  assert.equal(first.captureIntentId, "intent-home-1");
  const again = book.append({ captureIntentId: "intent-home-1", recordId: "goal-home-1", scoringTeamId: "team-alpha-001" });
  assert.equal(again.ok, true);
  assert.equal(again.reason, "idempotent");
  assert.equal(again.entries.length, 1);
});

test("a journal one frame ahead of the manifest reconciles only the pending intent", () => {
  const goals = createMemoryGoalStore();
  const journal = createGoalJournal(goals, context);
  assert.equal(journal.append({ captureIntentId: "intent-home-1", recordId: "goal-home-1", scoringTeamId: "team-alpha-001" }).ok, true);
  const manifest = createMemoryPendingStore();
  manifest.raw = canonicalManifest({
    matchId: context.matchId,
    generation: 1,
    writerDeviceId: context.writerDeviceId,
    acknowledgedSequence: 0,
    lastFrameHash: null,
  });
  const pending = createMemoryPendingStore();
  const blocked = recoverGoalHistory(goals, manifest, pending, context);
  assert.equal(blocked.ok, false);
  assert.equal(blocked.reason, "journal-ahead");
  pending.raw = canonicalPending({
    matchId: context.matchId,
    scoringTeamId: "team-alpha-001",
    captureIntentId: "intent-home-1",
    recordId: "goal-home-1",
  });
  const reconciled = recoverGoalHistory(goals, manifest, pending, context);
  assert.equal(reconciled.ok, true);
  assert.equal(reconciled.reason, "reconciled");
  assert.equal(JSON.parse(manifest.raw).acknowledgedSequence, 1);
  assert.equal(JSON.parse(manifest.raw).lastFrameHash, goalFrameHash(journal.load().entries[0]));
});

test("a manifest ahead of a missing journal is not a healthy 0-0", () => {
  const goals = createMemoryGoalStore();
  const manifest = createMemoryPendingStore();
  manifest.raw = '{"schema":"forref.watch-goal-manifest.v2","matchId":"match-watch-001","generation":1,"writerDeviceId":"6f1e2d3c-4b5a-4678-9abc-def012345678","journalSchema":"forref.watch-goal.v1","acknowledgedSequence":1,"lastFrameHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}';
  const recovered = recoverGoalHistory(goals, manifest, createMemoryPendingStore(), context);
  assert.equal(recovered.ok, false);
  assert.equal(recovered.reason, "manifest-ahead");
  assert.equal(recovered.entries.length, 0);
});

test("an unassignable legacy journal is not opened", () => {
  const files = {
    [INSTALLATION_FILE]: fixture.localInstallationId,
    [PROVISION_ROOT_FILE]: fixture.canonical,
    [PROVISION_ADMISSION_FILE]: stageMarker(fixture.contentHash, "WATCH_ACTIVATED"),
    [GOAL_JOURNAL_LEGACY_FILE]: "NOT-A-JOURNAL",
  };
  const fs = mapFs(files, {
    openSync() {
      throw new Error("opened");
    },
  });
  const opened = openLocalGoal(fs, "");
  assert.equal(opened.ok, false);
  assert.equal(opened.reason, "journal-corrupt");
  assert.equal(opened.journal, null);
  assert.equal(files[GOAL_JOURNAL_LEGACY_FILE], "NOT-A-JOURNAL");
});

test("the live clock path still does not read the goal journal", () => {
  const live = readFileSync(new URL("../page/gt/live/index.page.js", import.meta.url), "utf8");
  const cadence = readFileSync(new URL("../utils/clock_cadence.js", import.meta.url), "utf8");
  const foreground = readFileSync(new URL("../utils/clock_foreground_bind.js", import.meta.url), "utf8");
  const paint = live.slice(live.indexOf("function paintAll"), live.indexOf("function onAction"));
  assert.equal(paint.includes("createFileGoalStore"), false);
  assert.equal(paint.includes("readFileSync"), false);
  assert.equal(paint.includes("sha256"), false);
  assert.equal(live.includes("createTimer"), false);
  assert.equal(live.includes("bindLivePaint"), true);
  assert.equal(foreground.includes("createTimer(delay, 1000, run)"), true);
  assert.equal(cadence.includes("nextTimerDelay"), true);
});
