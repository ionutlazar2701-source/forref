// Bounded chunk writer. A flush stats one new file. It does not parse older chunks.

import { MAX_BYTES, fnv1a, stableStringify } from "./journal.js";

export const COUNTER_FILE = "forref_sens_v2.counter";

function line(record, seq) {
  const body = stableStringify(Object.assign({ seq: seq, schema: 2 }, record));
  return "S2|E|" + seq + "|" + body.length + "|" + fnv1a(body) + "|" + body + "\n";
}

export function createChunkStore(adapter) {
  let chunks = 0;
  let bytes = 0;
  let nextSeq = 1;

  function nextSessionId() {
    let current = 0;
    try {
      const raw = adapter.readCounter();
      const match = typeof raw === "string" ? raw.match(/^S2\|N\|(\d+)\n$/) : null;
      current = match ? Number(match[1]) : 0;
    } catch (err) {
      return { ok: false, sessionId: "", reason: "COUNTER_UNVERIFIED" };
    }
    const next = current + 1;
    const text = "S2|N|" + next + "\n";
    let written;
    try {
      written = adapter.writeCounter(text);
    } catch (err) {
      return { ok: false, sessionId: "", reason: "COUNTER_UNVERIFIED" };
    }
    if (written !== text.length) {
      return { ok: false, sessionId: "", reason: "SHORT_WRITE" };
    }
    return { ok: true, sessionId: "V2-" + String(next).padStart(4, "0"), reason: "" };
  }

  function flush(sessionId, records) {
    const batch = records || [];
    if (batch.length === 0) {
      return { ok: true, empty: true, bytes: bytes, uncertified: 0 };
    }
    let payload = "S2|C|" + sessionId + "|" + batch.length + "\n";
    for (let i = 0; i < batch.length; i++) {
      payload += line(batch[i], nextSeq + i);
    }
    if (bytes + payload.length > MAX_BYTES) {
      return { ok: false, reason: "CAPACITY", uncertified: batch.length, bytes: bytes };
    }
    const name = "v2_" + sessionId + "_" + String(chunks).padStart(3, "0") + ".chk";
    let written;
    try {
      written = adapter.writeChunk(name, payload);
    } catch (err) {
      return { ok: false, reason: "WRITE_EXCEPTION", uncertified: batch.length, bytes: bytes };
    }
    if (written !== payload.length) {
      return { ok: false, reason: "SHORT_WRITE", uncertified: batch.length, bytes: bytes };
    }
    let size;
    try {
      size = adapter.statChunk(name);
    } catch (err) {
      return { ok: false, reason: "UNVERIFIED", uncertified: batch.length, bytes: bytes };
    }
    if (size !== payload.length) {
      return { ok: false, reason: "UNVERIFIED", uncertified: batch.length, bytes: bytes };
    }
    nextSeq += batch.length;
    chunks += 1;
    bytes += payload.length;
    return { ok: true, reason: "", bytes: bytes, chunks: chunks, uncertified: 0, saved: false };
  }

  return {
    nextSessionId: nextSessionId,
    flush: flush,
    bytes: () => bytes,
  };
}

export function memoryChunkAdapter() {
  const files = {};
  let counter = "";
  return {
    files: files,
    reads: 0,
    writes: 0,
    readCounter() {
      this.reads += 1;
      return counter;
    },
    writeCounter(text) {
      this.writes += 1;
      counter = text;
      return text.length;
    },
    writeChunk(name, text) {
      this.writes += 1;
      if (this.mode === "throw") {
        throw new Error("disk");
      }
      if (this.mode === "short") {
        files[name] = text.slice(0, 4);
        return 4;
      }
      files[name] = text;
      return text.length;
    },
    statChunk(name) {
      if (this.mode === "nostat") {
        throw new Error("stat");
      }
      return files[name] ? files[name].length : 0;
    },
    readAll() {
      this.reads += 1;
      return "";
    },
  };
}
