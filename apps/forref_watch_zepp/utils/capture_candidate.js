// Provisional watch-local capture candidates.
// This journal is not Match Memory, not D1, and not a match report.

export const SCHEMA_VERSION = 1;
export const NAMESPACE = "forref_capture_bridge_001";
export const JOURNAL_FILE = "forref_capture_bridge_001.journal";
export const MAX_ENTRIES = 32;
export const MAX_BYTES = 16384;

export const FIXTURE = {
  matchId: "SIM_MATCH_001",
  homeTeamId: "SIM_TEAM_HOME",
  awayTeamId: "SIM_TEAM_AWAY",
  deviceId: "SIM_DEVICE_001",
};

export const Admission = {
  VALID_STRUCTURED_CANDIDATE: "VALID_STRUCTURED_CANDIDATE",
  INCOMPLETE_IDENTITY: "INCOMPLETE_IDENTITY",
  UNSUPPORTED_SEMANTICS: "UNSUPPORTED_SEMANTICS",
  CONFLICT: "CONFLICT",
  CORRUPT: "CORRUPT",
  UNVERIFIED_STORAGE: "UNVERIFIED_STORAGE",
};

export const Evidence = {
  WRITTEN_UNVERIFIED: "WRITTEN_UNVERIFIED",
  READBACK_MATCHED: "READBACK_MATCHED",
  RECREATION_RECOVERED: "RECREATION_RECOVERED",
  HARDWARE_D1_UNCERTIFIED: "HARDWARE_D1_UNCERTIFIED",
};

const ID_PATTERN = /^[A-Z0-9_-]{4,64}$/;

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

function ascii(text) {
  for (let i = 0; i < text.length; i++) {
    if (text.charCodeAt(i) > 127) {
      return false;
    }
  }
  return true;
}

function teamIdFor(token, fixtureMode) {
  if (!fixtureMode) {
    return null;
  }
  if (token === "HOME") {
    return FIXTURE.homeTeamId;
  }
  if (token === "AWAY") {
    return FIXTURE.awayTeamId;
  }
  return null;
}

function payloadOf(kind, fields) {
  const body = { kind: kind };
  const names = Object.keys(fields);
  for (let i = 0; i < names.length; i++) {
    body[names[i]] = fields[names[i]];
  }
  return body;
}

export function assessCapture(input) {
  const source = input || {};
  const eventToken = source.eventToken || source.kind || "";
  const fixtureMode = source.fixtureMode === true;
  const matchId = fixtureMode ? FIXTURE.matchId : null;
  const deviceId = fixtureMode ? FIXTURE.deviceId : "UNPROVISIONED_DEVICE";
  const teamId = teamIdFor(source.teamToken, fixtureMode);
  let kind = "UNKNOWN";
  let admission = Admission.UNSUPPORTED_SEMANTICS;
  let identityTrust = fixtureMode ? "VERIFIED_FIXTURE" : "UNPROVISIONED";
  let payload = payloadOf("UNKNOWN", {});

  if (eventToken === "GOAL") {
    kind = "GOAL";
    if (fixtureMode && teamId && matchId) {
      admission = Admission.VALID_STRUCTURED_CANDIDATE;
      payload = payloadOf("GOAL", { matchTeamId: teamId });
    } else {
      admission = Admission.INCOMPLETE_IDENTITY;
      identityTrust = "UNPROVISIONED";
      payload = payloadOf("GOAL", { matchTeamId: null });
    }
  } else if (eventToken === "YELLOW") {
    kind = "YELLOW";
    admission = Admission.INCOMPLETE_IDENTITY;
    identityTrust = "UNPROVISIONED";
    payload = payloadOf("YELLOW", { participantId: null });
  } else if (eventToken === "RED") {
    kind = "RED_BUTTON";
    admission = Admission.UNSUPPORTED_SEMANTICS;
    identityTrust = "UNPROVISIONED";
    payload = payloadOf("RED_BUTTON", { sendOff: false });
  } else if (eventToken === "SUB") {
    kind = "SUBSTITUTION";
    admission = Admission.INCOMPLETE_IDENTITY;
    identityTrust = "UNPROVISIONED";
    payload = payloadOf("SUBSTITUTION", { incomingParticipantId: null, outgoingParticipantId: null });
  } else if (eventToken === "DIRECT_SEND_OFF") {
    kind = "DIRECT_SEND_OFF";
    const participant = source.participantId || null;
    if (fixtureMode && teamId && participant && ID_PATTERN.test(participant)) {
      admission = Admission.VALID_STRUCTURED_CANDIDATE;
      payload = payloadOf("DIRECT_SEND_OFF", { matchTeamId: teamId, participantId: participant, pathway: "direct" });
    } else {
      admission = Admission.INCOMPLETE_IDENTITY;
      identityTrust = "UNPROVISIONED";
      payload = payloadOf("DIRECT_SEND_OFF", { matchTeamId: null, participantId: null, pathway: "direct" });
    }
  } else if (eventToken === "SECOND_CAUTION_SEND_OFF") {
    kind = "SECOND_CAUTION_SEND_OFF";
    const deps = Array.isArray(source.dependencies) ? source.dependencies : [];
    const ready = fixtureMode && teamId && deps.length >= 2 && deps.every((item) => ID_PATTERN.test(item));
    if (ready) {
      admission = Admission.VALID_STRUCTURED_CANDIDATE;
      payload = payloadOf("SECOND_CAUTION_SEND_OFF", {
        matchTeamId: teamId,
        pathway: "secondCaution",
        dependencies: deps.slice(),
      });
    } else {
      admission = Admission.INCOMPLETE_IDENTITY;
      identityTrust = "UNPROVISIONED";
      payload = payloadOf("SECOND_CAUTION_SEND_OFF", {
        matchTeamId: null,
        pathway: "secondCaution",
        dependencies: [],
      });
    }
  }

  const canonical = stableStringify(payload);
  return {
    candidateSchemaVersion: SCHEMA_VERSION,
    matchId: matchId,
    kind: kind,
    canonicalCandidatePayload: payload,
    canonicalText: canonical,
    identityTrust: identityTrust,
    admissionState: admission,
    localOriginDeviceId: deviceId,
    createdUtcDiagnosticOnly: null,
    serializedLength: canonical.length,
    checksum: fnv1a(canonical),
  };
}

function headerLine(diagnosticDeviceSource) {
  const header = {
    schema: SCHEMA_VERSION,
    namespace: NAMESPACE,
    origin: "WATCH_LOCAL",
    diagnosticDeviceSource: diagnosticDeviceSource || "",
  };
  return "CB1|H|" + stableStringify(header) + "\n";
}

function entryLine(envelope) {
  const json = stableStringify(envelope);
  return "CB1|E|" + envelope.localSequence + "|" + json.length + "|" + fnv1a(json) + "|" + json + "\n";
}

function failRead(reason, header, prefix) {
  return {
    ok: false,
    quarantined: true,
    reason: reason,
    header: header || null,
    entries: [],
    readablePrefix: prefix || [],
    evidence: Evidence.WRITTEN_UNVERIFIED,
    d1: Evidence.HARDWARE_D1_UNCERTIFIED,
  };
}

function parseEntry(line, expectedSeq, seenIds) {
  if (!line.startsWith("CB1|E|")) {
    return { error: "CORRUPT_LINE" };
  }
  const body = line.slice("CB1|E|".length);
  const first = body.indexOf("|");
  const second = body.indexOf("|", first + 1);
  const third = body.indexOf("|", second + 1);
  if (first < 1 || second < 0 || third < 0) {
    return { error: "CORRUPT_LINE" };
  }
  const seq = Number(body.slice(0, first));
  const length = Number(body.slice(first + 1, second));
  const sum = body.slice(second + 1, third);
  const json = body.slice(third + 1);
  if (!Number.isInteger(seq) || seq !== expectedSeq) {
    return { error: "SEQUENCE_GAP" };
  }
  if (!Number.isInteger(length) || length !== json.length || json.length > 2000) {
    return { error: "LENGTH_MISMATCH" };
  }
  if (fnv1a(json) !== sum) {
    return { error: "CHECKSUM" };
  }
  let envelope;
  try {
    envelope = JSON.parse(json);
  } catch (err) {
    return { error: "CORRUPT_JSON" };
  }
  if (!envelope || envelope.localSequence !== seq || envelope.candidateSchemaVersion !== SCHEMA_VERSION) {
    return { error: "UNSUPPORTED_SCHEMA" };
  }
  if (envelope.checksum !== fnv1a(stableStringify(envelope.canonicalCandidatePayload))) {
    return { error: "CHECKSUM" };
  }
  if (envelope.serializedLength !== stableStringify(envelope.canonicalCandidatePayload).length) {
    return { error: "LENGTH_MISMATCH" };
  }
  if (seenIds[envelope.captureIntentId]) {
    return { error: "DUPLICATE_ID" };
  }
  seenIds[envelope.captureIntentId] = true;
  return { envelope: envelope };
}

export function parseJournal(raw) {
  if (raw == null || raw === "") {
    return {
      ok: true,
      empty: true,
      quarantined: false,
      reason: "",
      header: null,
      entries: [],
      readablePrefix: [],
      evidence: Evidence.RECREATION_RECOVERED,
      d1: Evidence.HARDWARE_D1_UNCERTIFIED,
    };
  }
  if (!ascii(raw)) {
    return failRead("CORRUPT_PREFIX", null, []);
  }
  let body = raw;
  let torn = false;
  if (!body.endsWith("\n")) {
    torn = true;
    const cut = body.lastIndexOf("\n");
    body = cut >= 0 ? body.slice(0, cut + 1) : "";
  }
  if (body === "") {
    return failRead("TORN_TAIL", null, []);
  }
  const lines = body.slice(0, -1).split("\n");
  if (!lines[0].startsWith("CB1|H|")) {
    return failRead("CORRUPT_PREFIX", null, []);
  }
  let header;
  try {
    header = JSON.parse(lines[0].slice("CB1|H|".length));
  } catch (err) {
    return failRead("CORRUPT_PREFIX", null, []);
  }
  if (!header || header.schema !== SCHEMA_VERSION || header.namespace !== NAMESPACE) {
    return failRead("UNSUPPORTED_SCHEMA", header, []);
  }
  const entries = [];
  const seen = {};
  for (let i = 1; i < lines.length; i++) {
    if (lines[i] === "") {
      return failRead("CORRUPT_LINE", header, entries);
    }
    const parsed = parseEntry(lines[i], entries.length + 1, seen);
    if (parsed.error) {
      return failRead(parsed.error, header, entries);
    }
    entries.push(parsed.envelope);
  }
  if (torn) {
    return failRead("TORN_TAIL", header, entries);
  }
  return {
    ok: true,
    empty: entries.length === 0,
    quarantined: false,
    reason: "",
    header: header,
    entries: entries,
    readablePrefix: entries,
    evidence: Evidence.RECREATION_RECOVERED,
    d1: Evidence.HARDWARE_D1_UNCERTIFIED,
  };
}

export function intentForCaptureTap(openIntentId, fresh) {
  if (fresh === true) {
    return "";
  }
  return openIntentId || "";
}

function rejected(reason, admission, snapshot, attemptedId) {
  return {
    ok: false,
    duplicate: false,
    admissionState: admission,
    reason: reason,
    evidence: Evidence.WRITTEN_UNVERIFIED,
    d1: Evidence.HARDWARE_D1_UNCERTIFIED,
    entry: null,
    attemptedId: attemptedId || "",
    entries: snapshot || [],
    readablePrefix: snapshot || [],
  };
}

function samePayload(entry, draft) {
  return (
    entry.matchId === draft.matchId &&
    entry.kind === draft.kind &&
    stableStringify(entry.canonicalCandidatePayload) === draft.canonicalText
  );
}

export function createJournal(adapter, options) {
  const limits = options || {};
  const maxEntries = limits.maxEntries || MAX_ENTRIES;
  const maxBytes = limits.maxBytes || MAX_BYTES;
  const diagnostic = limits.diagnosticDeviceSource || "";

  function snapshot() {
    try {
      const raw = adapter.readAll();
      if (typeof raw !== "string") {
        return failRead("READ_EXCEPTION", null, []);
      }
      const parsed = parseJournal(raw);
      parsed.raw = raw;
      return parsed;
    } catch (err) {
      return failRead("READ_EXCEPTION", null, []);
    }
  }

  function writeChunk(chunk) {
    let written;
    try {
      written = adapter.append(chunk);
    } catch (err) {
      const after = snapshot();
      return {
        ok: false,
        reason: "WRITE_EXCEPTION",
        admissionState: Admission.UNVERIFIED_STORAGE,
        evidence: Evidence.WRITTEN_UNVERIFIED,
        d1: Evidence.HARDWARE_D1_UNCERTIFIED,
        entries: after.readablePrefix || [],
        readablePrefix: after.readablePrefix || [],
        entry: null,
        attemptedId: "",
        duplicate: false,
      };
    }
    if (written !== chunk.length) {
      const after = snapshot();
      return {
        ok: false,
        reason: "SHORT_WRITE",
        admissionState: Admission.UNVERIFIED_STORAGE,
        evidence: Evidence.WRITTEN_UNVERIFIED,
        d1: Evidence.HARDWARE_D1_UNCERTIFIED,
        entries: after.readablePrefix || [],
        readablePrefix: after.readablePrefix || [],
        entry: null,
        attemptedId: "",
        duplicate: false,
      };
    }
    return null;
  }

  function append(input) {
    const before = snapshot();
    if (!before.ok) {
      const admission = before.reason === "READ_EXCEPTION" ? Admission.UNVERIFIED_STORAGE : Admission.CORRUPT;
      return rejected(before.reason || "QUARANTINE", admission, before.readablePrefix, input && input.captureIntentId);
    }
    const draft = assessCapture(input);
    const supplied = input && input.captureIntentId ? String(input.captureIntentId) : "";
    if (supplied && !ID_PATTERN.test(supplied)) {
      return rejected("BAD_ID", Admission.UNVERIFIED_STORAGE, before.entries, supplied);
    }
    if (supplied) {
      for (let i = 0; i < before.entries.length; i++) {
        const existing = before.entries[i];
        if (existing.captureIntentId === supplied) {
          if (samePayload(existing, draft)) {
            return {
              ok: true,
              duplicate: true,
              admissionState: existing.admissionState,
              reason: "IDEMPOTENT",
              evidence: Evidence.READBACK_MATCHED,
              d1: Evidence.HARDWARE_D1_UNCERTIFIED,
              entry: existing,
              attemptedId: existing.captureIntentId,
              entries: before.entries,
              readablePrefix: before.entries,
            };
          }
          return rejected("CONFLICT", Admission.CONFLICT, before.entries, supplied);
        }
      }
    }
    if (before.entries.length >= maxEntries) {
      return rejected("CAPACITY", Admission.UNVERIFIED_STORAGE, before.entries, supplied);
    }
    const seq = before.entries.length + 1;
    const intentId = supplied || "CB1-" + draft.localOriginDeviceId + "-" + String(seq).padStart(4, "0");
    const envelope = {
      admissionState: draft.admissionState,
      candidateId: intentId,
      candidateSchemaVersion: SCHEMA_VERSION,
      canonicalCandidatePayload: draft.canonicalCandidatePayload,
      captureIntentId: intentId,
      checksum: draft.checksum,
      createdUtcDiagnosticOnly: null,
      identityTrust: draft.identityTrust,
      kind: draft.kind,
      localOriginDeviceId: draft.localOriginDeviceId,
      localSequence: seq,
      matchId: draft.matchId,
      serializedLength: draft.serializedLength,
    };
    const line = entryLine(envelope);
    const header = before.header ? "" : headerLine(diagnostic);
    let measured;
    try {
      measured = adapter.readAll();
    } catch (err) {
      return rejected("READ_EXCEPTION", Admission.UNVERIFIED_STORAGE, before.readablePrefix, intentId);
    }
    if (typeof measured !== "string" || measured !== before.raw) {
      return rejected("READ_EXCEPTION", Admission.UNVERIFIED_STORAGE, before.readablePrefix, intentId);
    }
    if (measured.length + header.length + line.length > maxBytes) {
      return rejected("CAPACITY", Admission.UNVERIFIED_STORAGE, before.entries, intentId);
    }
    if (header) {
      const headerFault = writeChunk(header);
      if (headerFault) {
        headerFault.attemptedId = intentId;
        return headerFault;
      }
    }
    const entryFault = writeChunk(line);
    if (entryFault) {
      entryFault.attemptedId = intentId;
      return entryFault;
    }
    const after = snapshot();
    const found = after.ok ? after.entries.filter((item) => item.captureIntentId === intentId) : [];
    if (!after.ok || found.length !== 1 || !samePayload(found[0], draft) || after.entries.length !== before.entries.length + 1) {
      return {
        ok: false,
        duplicate: false,
        admissionState: Admission.UNVERIFIED_STORAGE,
        reason: "READBACK_MISMATCH",
        evidence: Evidence.WRITTEN_UNVERIFIED,
        d1: Evidence.HARDWARE_D1_UNCERTIFIED,
        entry: null,
        attemptedId: intentId,
        entries: after.readablePrefix || [],
        readablePrefix: after.readablePrefix || [],
      };
    }
    return {
      ok: true,
      duplicate: false,
      admissionState: found[0].admissionState,
      reason: "",
      evidence: Evidence.READBACK_MATCHED,
      d1: Evidence.HARDWARE_D1_UNCERTIFIED,
      entry: found[0],
      attemptedId: found[0].captureIntentId,
      entries: after.entries,
      readablePrefix: after.entries,
    };
  }

  return {
    fileName: JOURNAL_FILE,
    read: snapshot,
    append: append,
  };
}

export function memoryAdapter() {
  const store = { raw: "", mode: "ok" };
  return {
    store: store,
    readAll() {
      return store.raw;
    },
    append(text) {
      if (store.mode === "throw") {
        throw new Error("disk");
      }
      if (store.mode === "short") {
        const count = Math.min(4, text.length);
        store.raw += text.slice(0, count);
        return count;
      }
      store.raw += text;
      return text.length;
    },
  };
}
