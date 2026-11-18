import test from "node:test";
import assert from "node:assert/strict";
import { HR_STALE_MS, initialHr, reduceHr } from "../lib/hr_state.js";

test("a live callback is distinct from getLast and from null or unworn samples", () => {
  let state = reduceHr(initialHr(), { type: "measuring" });
  assert.equal(state.state, "MEASURING");
  assert.equal(state.live, false);
  state = reduceHr(state, { type: "last", bpm: 70 });
  assert.equal(state.state, "STALE");
  assert.equal(state.live, false);
  assert.equal(state.lastKnown, true);
  state = reduceHr(state, { type: "sample", bpm: 132 });
  assert.equal(state.state, "LIVE");
  assert.equal(state.live, true);
  assert.equal(state.lastKnown, false);
  const unworn = reduceHr(state, { type: "sample", bpm: 0 });
  assert.equal(unworn.state, "UNAVAILABLE");
  assert.equal(unworn.live, false);
  const missing = reduceHr(reduceHr(initialHr(), { type: "measuring" }), { type: "sample", bpm: null });
  assert.equal(missing.state, "UNAVAILABLE");
  assert.equal(reduceHr(initialHr(), { type: "permission" }).state, "PERMISSION_REQUIRED");
});

test("a live sample becomes stale without being presented as live", () => {
  let state = reduceHr(initialHr(), { type: "sample", bpm: 140 });
  state = reduceHr(state, { type: "tick", sampleAgeMs: HR_STALE_MS + 1 });
  assert.equal(state.state, "STALE");
  assert.equal(state.live, false);
  assert.equal(state.lastKnown, true);
});
