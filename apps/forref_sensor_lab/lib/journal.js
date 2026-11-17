// Research-only sample journal. Not Match Memory and not a durable commit.

export const SCHEMA = 1;
export const NAMESPACE = "forref_sens_001";
export const JOURNAL_FILE = "forref_sens_001.journal";
export const MAX_ENTRIES = 4096;
export const MAX_BYTES = 1048576;

export function fnv1a(text) {
  let hash = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  return (hash >>> 0).toString(16).padStart(8, "0");
}

export function stableStringify(value) {
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return "[" + value.map(stableStringify).join(",") + "]";
  }
  const keys = Object.keys(value).sort();
  return "{" + keys.map((key) => JSON.stringify(key) + ":" + stableStringify(value[key])).join(",") + "}";
}

function fail(reason, prefix) {
  return {
    ok: false,
    reason: reason,
    entries: [],
    readablePrefix: prefix || [],
    experimental: true,
  };
}

function asNumber(value) {
  return typeof value === "number" && isFinite(value) ? value : null;
}

function asText(value) {
  return typeof value === "string" ? value : "";
}

export function normalizeRecord(record, seq) {
  const source = record || {};
  const flags = Array.isArray(source.flags) ? source.flags.map(String) : [];
  return {
    attribution: "EXPERIMENTAL",
    batteryPercent: asNumber(source.batteryPercent),
    diagnosticElapsedMs: asNumber(source.diagnosticElapsedMs),
    diagnosticUtcMs: asNumber(source.diagnosticUtcMs),
    distanceAttribution: source.distanceAttribution || (source.kind === "DISTANCE" ? "UNRESOLVED" : ""),
    distanceRaw: asNumber(source.distanceRaw),
    distanceUnit: source.distanceUnit || (source.kind === "DISTANCE" ? "UNRESOLVED" : ""),
    experimental: true,
    flags: flags,
    fromSeq: asNumber(source.fromSeq),
    gapReason: asText(source.gapReason),
    gpsStatus: asText(source.gpsStatus),
    hrBpm: asNumber(source.hrBpm),
    kind: asText(source.kind),
    lat: asNumber(source.lat),
    lon: asNumber(source.lon),
    missingMs: asNumber(source.missingMs),
    name: asText(source.name),
    namespace: NAMESPACE,
    satellites: asNumber(source.satellites),
    schema: SCHEMA,
    seq: seq,
    sessionId: asText(source.sessionId),
    signal: asNumber(source.signal),
    source: asText(source.source) || "DEVICE_APP",
  };
}

function headerLine() {
  const body = stableStringify({ namespace: NAMESPACE, schema: SCHEMA });
  return "S1|H|" + body + "\n";
}

function entryLine(entry) {
  const body = stableStringify(entry);
  return "S1|E|" + entry.seq + "|" + body.length + "|" + fnv1a(body) + "|" + body + "\n";
}

export function parseJournal(raw) {
  if (raw == null || raw === "") {
    return { ok: true, empty: true, reason: "", entries: [], readablePrefix: [], experimental: true };
  }
  if (typeof raw !== "string" || raw.indexOf("\n") < 0) {
    return fail("TORN_TAIL", []);
  }
  const lines = raw.split("\n");
  if (lines[lines.length - 1] === "") {
    lines.pop();
  } else {
    return fail("TORN_TAIL", []);
  }
  let header;
  try {
    header = JSON.parse(lines[0].slice("S1|H|".length));
  } catch (err) {
    return fail("CORRUPT_PREFIX", []);
  }
  if (!lines[0].startsWith("S1|H|") || !header || header.schema !== SCHEMA || header.namespace !== NAMESPACE) {
    return fail("UNSUPPORTED_SCHEMA", []);
  }
  const entries = [];
  for (let i = 1; i < lines.length; i++) {
    const line = lines[i];
    if (!line.startsWith("S1|E|")) {
      return fail("CORRUPT_LINE", entries);
    }
    const body = line.slice("S1|E|".length);
    const first = body.indexOf("|");
    const second = body.indexOf("|", first + 1);
    const third = body.indexOf("|", second + 1);
    if (first < 0 || second < 0 || third < 0) {
      return fail("CORRUPT_LINE", entries);
    }
    const seq = Number(body.slice(0, first));
    const size = Number(body.slice(first + 1, second));
    const sum = body.slice(second + 1, third);
    const json = body.slice(third + 1);
    if (!isFinite(seq) || seq !== entries.length + 1 || json.length !== size || fnv1a(json) !== sum) {
      return fail(seq !== entries.length + 1 ? "SEQUENCE_GAP" : "CHECKSUM", entries);
    }
    let entry;
    try {
      entry = JSON.parse(json);
    } catch (err) {
      return fail("CORRUPT_LINE", entries);
    }
    if (!entry || entry.seq !== seq || entry.namespace !== NAMESPACE || entry.schema !== SCHEMA) {
      return fail("CORRUPT_LINE", entries);
    }
    entries.push(entry);
  }
  return { ok: true, empty: entries.length === 0, reason: "", entries: entries, readablePrefix: entries, experimental: true };
}

function rejected(reason, prefix) {
  return { ok: false, reason: reason, entry: null, entries: prefix || [], experimental: true };
}

export function createJournal(adapter, limits) {
  const maxEntries = (limits && limits.maxEntries) || MAX_ENTRIES;
  const maxBytes = (limits && limits.maxBytes) || MAX_BYTES;

  function snapshot() {
    try {
      const raw = adapter.readAll();
      if (typeof raw !== "string") {
        return fail("READ_EXCEPTION", []);
      }
      const parsed = parseJournal(raw);
      parsed.raw = raw;
      return parsed;
    } catch (err) {
      return fail("READ_EXCEPTION", []);
    }
  }

  function append(record) {
    const before = snapshot();
    if (!before.ok) {
      return rejected(before.reason || "QUARANTINE", before.readablePrefix);
    }
    if (before.entries.length >= maxEntries) {
      return rejected("CAPACITY", before.entries);
    }
    const entry = normalizeRecord(record, before.entries.length + 1);
    if (!entry.kind) {
      return rejected("BAD_RECORD", before.entries);
    }
    const line = entryLine(entry);
    const header = before.raw ? "" : headerLine();
    if ((before.raw || "").length + header.length + line.length > maxBytes) {
      return rejected("CAPACITY", before.entries);
    }
    let written;
    try {
      written = adapter.append(header + line);
    } catch (err) {
      return rejected("WRITE_EXCEPTION", before.entries);
    }
    if (written !== header.length + line.length) {
      return rejected("SHORT_WRITE", before.readablePrefix);
    }
    const after = snapshot();
    if (!after.ok || after.entries.length !== before.entries.length + 1) {
      return rejected("READBACK_MISMATCH", after.readablePrefix || []);
    }
    return { ok: true, reason: "", entry: after.entries[after.entries.length - 1], entries: after.entries, experimental: true };
  }

  function clear() {
    try {
      const result = adapter.clear();
      if (result === false) {
        return { ok: false, reason: "CLEAR_FAILED" };
      }
    } catch (err) {
      return { ok: false, reason: "CLEAR_FAILED" };
    }
    const after = snapshot();
    if (!after.ok || after.entries.length !== 0) {
      return { ok: false, reason: "CLEAR_UNVERIFIED" };
    }
    return { ok: true, reason: "" };
  }

  function nextSessionId() {
    const loaded = snapshot();
    const starts = loaded.ok ? loaded.entries.filter((entry) => entry.kind === "LIFECYCLE" && entry.name === "START").length : 0;
    return "LAB-" + String(starts + 1).padStart(4, "0");
  }

  return { fileName: JOURNAL_FILE, read: snapshot, append: append, clear: clear, nextSessionId: nextSessionId };
}

export function memoryAdapter() {
  const store = { raw: "", mode: "ok" };
  return {
    store: store,
    readAll() {
      if (store.mode === "throw-read") {
        throw new Error("read");
      }
      return store.raw;
    },
    append(text) {
      if (store.mode === "throw") {
        throw new Error("disk");
      }
      if (store.mode === "short") {
        store.raw += text.slice(0, 4);
        return 4;
      }
      store.raw += text;
      return text.length;
    },
    clear() {
      if (store.mode === "throw-clear") {
        throw new Error("clear");
      }
      store.raw = "";
      return true;
    },
  };
}
