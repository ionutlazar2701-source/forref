import test from "node:test";
import assert from "node:assert/strict";
import { FRESH_MS, LOST_MS, initialGps, reduceGps } from "../lib/gps_state.js";

function sample(extra) {
  return Object.assign({ type: "sample", status: "A", lat: 0, lon: 0, elapsedMs: 0, metaPresent: false }, extra);
}

test("searching, ready, stale, lost, and recovered do not stop acquisition", () => {
  let state = reduceGps(initialGps(), { type: "start" });
  assert.equal(state.state, "SEARCHING");
  assert.equal(state.acquiring, true);
  state = reduceGps(state, sample({ elapsedMs: 1000 }));
  assert.equal(state.state, "READY");
  assert.equal(state.accept, true);
  assert.equal(state.bridge, false);
  state = reduceGps(state, { type: "tick", elapsedMs: 1000 + FRESH_MS + 1 });
  assert.equal(state.state, "WEAK_OR_STALE");
  assert.equal(state.acquiring, true);
  assert.equal(state.gapOpen, true);
  state = reduceGps(state, { type: "tick", elapsedMs: 1000 + LOST_MS + 1 });
  assert.equal(state.state, "LOST");
  state = reduceGps(state, sample({ lat: 0.01, lon: 0, elapsedMs: 1000 + LOST_MS + 2 }));
  assert.equal(state.transition, "RECOVERED");
  assert.equal(state.accept, true);
  assert.equal(state.bridge, false);
  assert.equal(state.acquiring, true);
});

test("an invalid status keeps searching and zero satellites do not stop the receiver", () => {
  let state = reduceGps(initialGps(), { type: "start" });
  state = reduceGps(state, sample({ status: "V", lat: null, lon: null }));
  assert.equal(state.state, "SEARCHING");
  assert.equal(state.accept, false);
  state = reduceGps(state, sample({ elapsedMs: 1000 }));
  state = reduceGps(state, sample({
    elapsedMs: 2000,
    metaPresent: true,
    satellitesUsed: 0,
    satellitesValid: 4,
    signal: 10,
  }));
  assert.equal(state.state, "WEAK_OR_STALE");
  assert.equal(state.accept, false);
  assert.equal(state.acquiring, true);
  assert.equal(state.meta.quality, "PRESENT");
});

test("permission and error are explicit and missing metadata stays unavailable", () => {
  assert.equal(reduceGps(initialGps(), { type: "permission" }).state, "PERMISSION_REQUIRED");
  assert.equal(reduceGps(initialGps(), { type: "unsupported" }).state, "UNSUPPORTED");
  const failed = reduceGps(reduceGps(initialGps(), { type: "start" }), { type: "error" });
  assert.equal(failed.state, "ERROR");
  assert.equal(failed.acquiring, true);
  const ready = reduceGps(reduceGps(initialGps(), { type: "start" }), sample({ elapsedMs: 5 }));
  assert.equal(ready.meta.quality, "UNAVAILABLE");
  assert.equal(ready.meta.satellitesUsed, null);
});
