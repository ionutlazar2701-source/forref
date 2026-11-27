import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  GOAL_JOURNAL_LEGACY_FILE,
  createFileGoalStore,
  createGoalJournal,
  createMemoryGoalStore,
  parseGoalJournal,
  selectGoalJournalPath,
} from "../utils/goal_journal.js";
import { admitLocalGoal } from "../utils/goal_admission.js";
import {
  canonicalPending,
  commitGoalCapture,
  createMemoryPendingStore,
  resumeGoalCapture,
} from "../utils/goal_capture.js";
import { createMemoryProvisionStore, createWatchProvisionAdmission } from "../utils/watch_provision.js";
import { createLocalScoreCache, localTestPresentation, localTestScore } from "../utils/local_test_score.js";

const context = {
  matchId: "match-watch-001",
  principalId: "referee-001",
  writerDeviceId: "6f1e2d3c-4b5a-4678-9abc-def012345678",
  localInstallationId: "6f1e2d3c-4b5a-4678-9abc-def012345678",
  homeTeamId: "team-alpha-001",
  awayTeamId: "team-beta-001",
  authorityActivated: true,
};

function goal(over) {
  return Object.assign({
    captureIntentId: "intent-home-1",
    recordId: "goal-home-1",
    scoringTeamId: "team-alpha-001",
  }, over || {});
}

function decode(buffer, length) {
  const bytes = new Uint8Array(buffer);
  let out = "";
  const n = length == null ? bytes.length : length;
  for (let i = 0; i < n; i += 1) out += String.fromCharCode(bytes[i]);
  return out;
}

test("an interrupted third append keeps the two accepted frames", () => {
  const files = {};
  const attempted = [];
  let appends = 0;
  const fs = {
    O_RDONLY: 0,
    O_WRONLY: 1,
    O_CREAT: 0x0200,
    O_APPEND: 0x0008,
    readFileSync(request) {
      if (!Object.prototype.hasOwnProperty.call(files, request.path)) {
        const error = new Error("ENOENT: not found");
        throw error;
      }
      return files[request.path];
    },
    writeFileSync(request) {
      appends += 1;
      attempted.push(String(request.data));
      if (appends >= 3) {
        files[request.path] = String(request.data).slice(0, 24);
        return;
      }
      files[request.path] = String(request.data);
    },
    openSync(request) {
      const append = (request.flag & fs.O_APPEND) !== 0;
      const creat = (request.flag & fs.O_CREAT) !== 0;
      const write = (request.flag & fs.O_WRONLY) !== 0;
      if (!append || !creat || !write) {
        throw new Error("append-flags");
      }
      return { path: request.path };
    },
    writeSync(request) {
      appends += 1;
      const text = decode(request.buffer, request.options.length);
      attempted.push(text);
      const prior = files[request.fd.path] || "";
      const chunk = appends >= 3 ? text.slice(0, 12) : text;
      files[request.fd.path] = prior + chunk;
      return chunk.length;
    },
    closeSync() {},
  };
  const book = createGoalJournal(createFileGoalStore(fs, "match-journal"), context);
  assert.equal(book.append(goal({ captureIntentId: "intent-a", recordId: "goal-a" })).ok, true);
  assert.equal(book.append(goal({ captureIntentId: "intent-b", recordId: "goal-b" })).ok, true);
  const prefix = files["match-journal"];
  const parsedPrefix = parseGoalJournal(prefix);
  assert.equal(parsedPrefix.status, "ok");
  assert.equal(parsedPrefix.entries.length, 2);
  const third = book.append(goal({ captureIntentId: "intent-c", recordId: "goal-c" }));
  assert.equal(third.ok, false);
  assert.equal(third.uncertain, true);
  assert.equal(String(files["match-journal"]).startsWith(prefix), true);
  assert.equal(parseGoalJournal(files["match-journal"]).entries.length, 2);
  assert.equal(attempted[2].includes("intent-a"), false);
  const fourth = book.append(goal({ captureIntentId: "intent-d", recordId: "goal-d" }));
  assert.equal(fourth.ok, false);
  assert.equal(String(files["match-journal"]).startsWith(prefix), true);
  const source = readFileSync(new URL("../utils/goal_journal.js", import.meta.url), "utf8");
  assert.equal(source.includes("O_APPEND"), true);
  assert.equal(source.includes("writeFileSync"), false);
});

test("a foreign match does not become a numerical score", () => {
  const store = createMemoryGoalStore();
  const home = createGoalJournal(store, context);
  assert.equal(home.append(goal()).ok, true);
  const foreign = localTestScore(home.load().entries, Object.assign({}, context, {
    matchId: "match-other",
  }), "ok");
  assert.equal(foreign.home, null);
  assert.equal(foreign.away, null);
  assert.notEqual(foreign.kind, "local-test");
});

test("the live paint path does not read the journal on each tick", () => {
  const live = readFileSync(new URL("../page/gt/live/index.page.js", import.meta.url), "utf8");
  const paint = live.slice(live.indexOf("function paintAll"), live.indexOf("function onAction"));
  assert.equal(live.includes("createTimer"), false);
  assert.equal(live.includes("bindLivePaint"), true);
  assert.equal(paint.includes("goalPreview"), false);
  assert.equal(paint.includes("createFileGoalStore"), false);
  assert.equal(paint.includes("createGoalJournal"), false);
  assert.equal(paint.includes("readFileSync"), false);
  assert.equal(paint.includes("sha256"), false);
  assert.equal(paint.includes("parseGoalJournal"), false);
});

test("test numerals are withheld when LOCAL TEST cannot be shown", () => {
  const live = readFileSync(new URL("../page/gt/live/index.page.js", import.meta.url), "utf8");
  assert.equal(live.includes("localTestPresentation"), true);
  const labels = live.slice(live.indexOf("function teamButtonLabel"), live.indexOf("function telemetryLabel"));
  assert.equal(labels.includes("preview.home"), false);
});

test("installation identity is not copied from the goal context writer", () => {
  const live = readFileSync(new URL("../page/gt/live/index.page.js", import.meta.url), "utf8");
  const review = readFileSync(new URL("../page/gt/review/index.page.js", import.meta.url), "utf8");
  assert.equal(live.includes("localInstallationId: context.writerDeviceId"), false);
  assert.equal(review.includes("localInstallationId: context.writerDeviceId"), false);
  assert.equal(review.includes("readGoalContext"), false);
});

test("a fresh confirm screen does not mint a capture intent", () => {
  const review = readFileSync(new URL("../page/gt/review/index.page.js", import.meta.url), "utf8");
  assert.equal(review.includes("Date.now().toString(36)"), false);
  assert.equal(review.includes("resumeGoalCapture"), true);
});

test("process recreation with a fresh UI reuses the pending intent", () => {
  const pending = createMemoryPendingStore();
  const goals = createMemoryGoalStore();
  const firstUi = {};
  const started = resumeGoalCapture({
    pendingStore: pending,
    journal: createGoalJournal(goals, context),
    ui: firstUi,
    matchId: context.matchId,
    scoringTeamId: context.homeTeamId,
    userAction: true,
  });
  assert.equal(started.action, "READY");
  const fresh = {};
  const resumed = resumeGoalCapture({
    pendingStore: pending,
    journal: createGoalJournal(goals, context),
    ui: fresh,
    matchId: context.matchId,
    scoringTeamId: context.awayTeamId,
    userAction: true,
  });
  assert.equal(resumed.captureIntentId, started.captureIntentId);
  assert.equal(resumed.scoringTeamId, context.homeTeamId);
  assert.equal(fresh.goalIntentId, started.captureIntentId);
  goals.failWrite = true;
  const interrupted = commitGoalCapture({
    pendingStore: pending,
    journal: createGoalJournal(goals, context),
    ui: {},
    matchId: context.matchId,
  });
  assert.equal(interrupted.ok, false);
  assert.equal(interrupted.uncertain, true);
  const afterCrash = {};
  const recovered = resumeGoalCapture({
    pendingStore: pending,
    journal: createGoalJournal(goals, context),
    ui: afterCrash,
    matchId: context.matchId,
    scoringTeamId: context.awayTeamId,
    userAction: true,
  });
  assert.equal(recovered.captureIntentId, started.captureIntentId);
  goals.failWrite = false;
  const committed = commitGoalCapture({
    pendingStore: pending,
    journal: createGoalJournal(goals, context),
    ui: {},
    matchId: context.matchId,
  });
  assert.equal(committed.ok, true);
  assert.equal(committed.entry.captureIntentId, started.captureIntentId);
  assert.equal(parseGoalJournal(goals.raw).entries.length, 1);
});

test("a verified pending intent is not recorded twice after recreation", () => {
  const pending = createMemoryPendingStore();
  const goals = createMemoryGoalStore();
  const started = resumeGoalCapture({
    pendingStore: pending,
    journal: createGoalJournal(goals, context),
    ui: {},
    matchId: context.matchId,
    scoringTeamId: context.homeTeamId,
    userAction: true,
  });
  const committed = commitGoalCapture({
    pendingStore: pending,
    journal: createGoalJournal(goals, context),
    ui: {},
    matchId: context.matchId,
  });
  assert.equal(committed.ok, true);
  pending.raw = null;
  establishAgain(pending, started);
  const fresh = {};
  const recovered = commitGoalCapture({
    pendingStore: pending,
    journal: createGoalJournal(goals, context),
    ui: fresh,
    matchId: context.matchId,
  });
  assert.equal(recovered.ok, true);
  assert.equal(recovered.reason, "idempotent");
  assert.equal(parseGoalJournal(goals.raw).entries.length, 1);
  assert.equal(fresh.goalIntentId, started.captureIntentId);
});

function establishAgain(pending, started) {
  pending.raw = canonicalPending({
    matchId: context.matchId,
    scoringTeamId: context.homeTeamId,
    captureIntentId: started.captureIntentId,
    recordId: started.recordId,
  });
}

test("another match keeps its own journal and leaves the legacy bytes untouched", () => {
  const files = {};
  const fs = fileFs(files);
  const legacy = createGoalJournal(createFileGoalStore(fs, GOAL_JOURNAL_LEGACY_FILE), context);
  assert.equal(legacy.append(goal({ captureIntentId: "intent-a", recordId: "goal-a" })).ok, true);
  assert.equal(legacy.append(goal({ captureIntentId: "intent-b", recordId: "goal-b" })).ok, true);
  const preserved = files[GOAL_JOURNAL_LEGACY_FILE];
  assert.equal(selectGoalJournalPath(fs, context.matchId).path, GOAL_JOURNAL_LEGACY_FILE);
  const otherId = "match-other";
  const selected = selectGoalJournalPath(fs, otherId);
  assert.notEqual(selected.path, GOAL_JOURNAL_LEGACY_FILE);
  const otherContext = Object.assign({}, context, { matchId: otherId });
  const other = createGoalJournal(createFileGoalStore(fs, selected.path), otherContext);
  assert.equal(other.append(goal({ captureIntentId: "intent-c", recordId: "goal-c" })).ok, true);
  assert.equal(files[GOAL_JOURNAL_LEGACY_FILE], preserved);
  const foreign = localTestScore(other.load().entries, context, "ok");
  assert.equal(foreign.home, null);
  const own = localTestScore(other.load().entries, otherContext, other.load().status);
  assert.equal(own.home, 1);
  assert.equal(own.knownScore, false);
});

test("a goal context document is not the installation identity", () => {
  const fixture = JSON.parse(readFileSync(new URL("../../../packages/forref_match_core/test/fixtures/watch_provision_v1.json", import.meta.url), "utf8"));
  const provision = createMemoryProvisionStore();
  const admission = createWatchProvisionAdmission(provision);
  admission.receive(fixture.canonical, fixture.localInstallationId, false);
  admission.activate(fixture.localInstallationId, {
    contentHash: fixture.contentHash,
    writerDeviceId: fixture.localInstallationId,
    generation: 1,
    durable: true,
  });
  let writes = 0;
  const installation = {
    raw: fixture.localInstallationId,
    read() {
      return { status: "ok", text: this.raw };
    },
    write() {
      writes += 1;
      throw new Error("regenerated");
    },
  };
  const admitted = admitLocalGoal({
    matchId: "match-watch-001",
    installationStore: installation,
    provisionStore: provision,
    contextDocument: {
      authorityActivated: true,
      writerDeviceId: "00000000-0000-4000-8000-000000000099",
      matchId: "match-watch-001",
    },
  });
  assert.equal(admitted.localCandidate, true);
  assert.equal(admitted.localInstallationId, fixture.localInstallationId);
  assert.equal(admitted.authoritativeCaptureAdmitted, false);
  assert.equal(admitted.captureStorageCertified, false);
  assert.equal(writes, 0);
  installation.raw = "";
  const missing = admitLocalGoal({
    installationStore: installation,
    provisionStore: provision,
    contextDocument: { authorityActivated: true, writerDeviceId: fixture.localInstallationId },
  });
  assert.equal(missing.localCandidate, false);
  assert.equal(missing.reason, "missing-installation");
  assert.equal(writes, 0);
});

test("five score paints do not read the journal again", () => {
  const cache = createLocalScoreCache();
  let reads = 0;
  function refresh() {
    reads += 1;
    cache.publish({ kind: "local-test", knownScore: false, home: 1, away: 0 });
  }
  refresh();
  for (let i = 0; i < 5; i += 1) {
    assert.equal(cache.paint().home, 1);
  }
  assert.equal(reads, 1);
  cache.invalidate();
  assert.equal(cache.paint(), null);
  refresh();
  assert.equal(reads, 2);
  const labels = { homeScore: "HOME · NO SCORE", awayScore: "AWAY · NO SCORE", home: "HOME", away: "AWAY", conflict: "SCORE CONFLICT", localTest: "LOCAL TEST" };
  const withheld = localTestPresentation(cache.paint(), false, labels);
  assert.equal(withheld.numerals, false);
  assert.equal(withheld.warning, "");
  assert.equal(withheld.home.includes("1"), false);
  const shown = localTestPresentation(cache.paint(), true, labels);
  assert.equal(shown.warning, "LOCAL TEST");
  assert.equal(shown.home, "HOME 1");
  assert.equal(shown.away, "AWAY 0");
});

function fileFs(files) {
  return {
    O_RDONLY: 0,
    O_WRONLY: 1,
    O_CREAT: 0x0200,
    O_APPEND: 0x0008,
    readFileSync(request) {
      if (!Object.prototype.hasOwnProperty.call(files, request.path)) throw new Error("ENOENT: not found");
      return files[request.path];
    },
    openSync(request) {
      if ((request.flag & 0x0008) === 0 || (request.flag & 0x0200) === 0) throw new Error("append-flags");
      return { path: request.path };
    },
    writeSync(request) {
      const bytes = new Uint8Array(request.buffer);
      let text = "";
      for (let i = 0; i < request.options.length; i += 1) text += String.fromCharCode(bytes[i]);
      files[request.fd.path] = (files[request.fd.path] || "") + text;
      return request.options.length;
    },
    closeSync() {},
  };
}
