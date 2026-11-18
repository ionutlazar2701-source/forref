import test from "node:test";
import assert from "node:assert/strict";
import { createChunkStore, memoryChunkAdapter } from "../lib/chunk_store.js";

test("a chunk flush verifies one file and a short write stays unverified", () => {
  const adapter = memoryChunkAdapter();
  const store = createChunkStore(adapter);
  const id = store.nextSessionId();
  assert.equal(id.sessionId, "V2-0001");
  const ok = store.flush(id.sessionId, [{ kind: "HR", sessionId: id.sessionId, elapsedMs: 1, accepted: 1, hrBpm: 120 }]);
  assert.equal(ok.ok, true);
  assert.equal(ok.saved, false);
  assert.equal(adapter.files["v2_V2-0001_000.chk"].includes("S2|E|1|"), true);
  adapter.mode = "short";
  const bad = store.flush(id.sessionId, [{ kind: "HR", sessionId: id.sessionId, elapsedMs: 2, accepted: 1, hrBpm: 121 }]);
  assert.equal(bad.ok, false);
  assert.equal(bad.reason, "SHORT_WRITE");
  assert.equal(bad.uncertified, 1);
});

test("a corrupt counter does not invent a session id", () => {
  const adapter = memoryChunkAdapter();
  adapter.readCounter = () => {
    throw new Error("torn");
  };
  const id = createChunkStore(adapter).nextSessionId();
  assert.equal(id.ok, false);
  assert.equal(id.sessionId, "");
  assert.equal(id.reason, "COUNTER_UNVERIFIED");
});
