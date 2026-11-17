import test from "node:test";
import assert from "node:assert/strict";
import { MAX_BYTES, MAX_ENTRIES, createJournal, memoryAdapter, parseJournal, refereeStorageLimit } from "../lib/journal.js";

function sample(extra) {
  return Object.assign({
    kind: "GNSS",
    sessionId: "LAB-0001",
    gpsStatus: "A",
    lat: 0.001,
    lon: 0.001,
    diagnosticElapsedMs: 1000,
    source: "DEVICE_APP",
    flags: [],
  }, extra);
}

test("a missing journal is empty and a torn tail does not append", () => {
  const adapter = memoryAdapter();
  const book = createJournal(adapter);
  assert.equal(book.read().ok, true);
  assert.equal(book.read().entries.length, 0);
  const kept = book.append(sample());
  assert.equal(kept.ok, true);
  adapter.store.raw += "S1|E|2|4|abcd|";
  const torn = parseJournal(adapter.store.raw);
  assert.equal(torn.ok, false);
  assert.equal(torn.reason, "TORN_TAIL");
  const blocked = book.append(sample({ diagnosticElapsedMs: 2000 }));
  assert.equal(blocked.ok, false);
  assert.equal(adapter.store.raw.includes("2000"), false);
});

test("capacity, short write, and delete keep the research file bounded", () => {
  const adapter = memoryAdapter();
  const book = createJournal(adapter, { maxEntries: 2, maxBytes: 1048576 });
  assert.equal(book.append(sample()).ok, true);
  assert.equal(book.append(sample({ diagnosticElapsedMs: 2000, lat: 0.002 })).ok, true);
  const full = book.append(sample({ diagnosticElapsedMs: 3000 }));
  assert.equal(full.ok, false);
  assert.equal(full.reason, "CAPACITY");
  assert.equal(book.read().entries.length, 2);
  const other = memoryAdapter();
  other.store.mode = "short";
  const torn = createJournal(other).append(sample());
  assert.equal(torn.ok, false);
  assert.equal(torn.reason, "SHORT_WRITE");
  const cleared = book.clear();
  assert.equal(cleared.ok, true);
  assert.equal(book.read().entries.length, 0);
  assert.equal(book.read().empty, true);
});

test("a 90 minute one-hertz GNSS and heart-rate session does not fit", () => {
  const limit = refereeStorageLimit();
  assert.equal(limit.enduranceReady, false);
  assert.equal(limit.fitsNinetyMinutes, false);
  assert.equal(limit.entriesRequired, 10800);
  assert.equal(limit.bytesRequired, 4989648);
  assert.equal(limit.practicalSeconds, 1134);
  assert.equal(limit.limitingFactor, "BYTES");
  assert.equal(limit.gnssLineBytes, 458);
  assert.equal(limit.hrLineBytes, 466);
  assert.ok(limit.entriesRequired > MAX_ENTRIES);
  assert.ok(limit.bytesRequired > MAX_BYTES);
  const book = createJournal(memoryAdapter());
  let stored = 0;
  let last = { ok: true };
  while (last.ok) {
    const kind = stored % 2 === 0 ? "GNSS" : "HR";
    last = book.append(sample({
      kind: kind,
      gpsStatus: kind === "GNSS" ? "A" : "",
      lat: kind === "GNSS" ? 0 : null,
      lon: kind === "GNSS" ? 0 : null,
      hrBpm: kind === "HR" ? 120 : null,
      diagnosticElapsedMs: stored * 1000,
      diagnosticUtcMs: 0,
      batteryPercent: kind === "GNSS" ? 50 : null,
      satellites: kind === "GNSS" ? 12 : null,
      signal: kind === "GNSS" ? 30 : null,
      flags: [],
    }));
    if (last.ok) {
      stored += 1;
    }
  }
  assert.equal(last.reason, "CAPACITY");
  assert.equal(book.read().entries.length, stored);
  assert.ok(stored < limit.entriesRequired);
  assert.ok(stored < MAX_ENTRIES);
  assert.ok(stored > limit.practicalPairs);
  assert.ok(book.read().raw.length <= MAX_BYTES);
});

test("session ids increase without rewriting earlier lines", () => {
  const book = createJournal(memoryAdapter());
  assert.equal(book.nextSessionId(), "LAB-0001");
  book.append({ kind: "LIFECYCLE", name: "START", sessionId: "LAB-0001", flags: [] });
  const before = book.read().entries[0].sessionId;
  assert.equal(book.nextSessionId(), "LAB-0002");
  assert.equal(book.read().entries[0].sessionId, before);
});
