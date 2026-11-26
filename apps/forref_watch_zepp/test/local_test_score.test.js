import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createGoalJournal, createMemoryGoalStore } from "../utils/goal_journal.js";
import { localTestScore } from "../utils/local_test_score.js";

const context = {
  matchId: "match-watch-001",
  principalId: "referee-001",
  writerDeviceId: "6f1e2d3c-4b5a-4678-9abc-def012345678",
  localInstallationId: "6f1e2d3c-4b5a-4678-9abc-def012345678",
  homeTeamId: "team-alpha-001",
  awayTeamId: "team-beta-001",
  authorityActivated: true,
};

const fixture = JSON.parse(
  readFileSync(new URL("../../../packages/forref_match_core/test/fixtures/watch_local_score_v1.json", import.meta.url), "utf8"),
);

test("a healthy empty journal is a local test 0-0 and not KnownScore", () => {
  const score = localTestScore([], context, "empty");
  assert.equal(score.kind, "local-test");
  assert.equal(score.home, 0);
  assert.equal(score.away, 0);
  assert.equal(score.knownScore, false);
});

test("goals rebuild 1-0 then 1-1 and a retry does not add a goal", () => {
  const store = createMemoryGoalStore();
  const book = createGoalJournal(store, context);
  assert.deepEqual(localTestScore(book.load().entries, context, book.load().status).home, 0);
  book.append({ captureIntentId: "intent-a", recordId: "goal-a", scoringTeamId: context.homeTeamId });
  let loaded = book.load();
  let score = localTestScore(loaded.entries, context, loaded.status);
  assert.equal(score.home, 1);
  assert.equal(score.away, 0);
  book.append({ captureIntentId: "intent-a", recordId: "goal-a", scoringTeamId: context.homeTeamId });
  loaded = book.load();
  score = localTestScore(loaded.entries, context, loaded.status);
  assert.equal(score.home, 1);
  book.append({ captureIntentId: "intent-b", recordId: "goal-b", scoringTeamId: context.awayTeamId });
  const reopened = createGoalJournal(store, context).load();
  score = localTestScore(reopened.entries, context, reopened.status);
  assert.equal(score.home, fixture.localTest.home);
  assert.equal(score.away, fixture.localTest.away);
  assert.equal(score.kind, fixture.localTest.kind);
  assert.equal(score.knownScore, false);
});

test("unavailable and conflicted history do not become zero", () => {
  assert.equal(localTestScore([], context, "unreadable").kind, "unavailable");
  assert.equal(localTestScore([], context, "torn").kind, "unavailable");
  assert.equal(localTestScore([], context, "corrupt").kind, "conflict");
  assert.equal(localTestScore([], { authorityActivated: false }, "empty").kind, "hidden");
  const foreign = localTestScore(
    [{ captureIntentId: "x", scoringTeamId: "team-other", semanticType: "GOAL" }],
    context,
    "ok",
  );
  assert.equal(foreign.kind, "unavailable");
  assert.equal(foreign.home, null);
});
