import { sha256Hex } from "./sha256_hex.js";

export const WATCH_GOAL_SCHEMA = "forref.watch-goal.v1";
export const GOAL_JOURNAL_FILE = "forref_watch_goal_journal_v1.journal";
export const GOAL_JOURNAL_LEGACY_FILE = GOAL_JOURNAL_FILE;
export const LOCAL_RECORD_LABEL = "LOCAL RECORD VERIFIED — D1 UNCERTIFIED";
export const MAX_GOAL_ENTRIES = 256;

export function canonicalWatchGoalV1(entry) {
  return '{"schema":"' + WATCH_GOAL_SCHEMA + '",' +
    '"matchId":' + JSON.stringify(entry.matchId) + "," +
    '"recordKind":"humanDetermination",' +
    '"semanticType":"GOAL",' +
    '"authority":{"scope":"MAIN_REFEREE",' +
    '"principalId":' + JSON.stringify(entry.principalId) + "," +
    '"generation":1,' +
    '"writerDeviceId":' + JSON.stringify(entry.writerDeviceId) + "}," +
    '"origin":{"deviceId":' + JSON.stringify(entry.writerDeviceId) + "," +
    '"sequence":' + entry.originSequence + "," +
    '"recordId":' + JSON.stringify(entry.recordId) + "}," +
    '"captureIntentId":' + JSON.stringify(entry.captureIntentId) + "," +
    '"scoringTeamId":' + JSON.stringify(entry.scoringTeamId) + "}";
}

function utf8ByteLength(text) {
  let n = 0;
  for (let i = 0; i < text.length; i += 1) {
    let code = text.charCodeAt(i);
    if (code >= 0xd800 && code <= 0xdbff && i + 1 < text.length) {
      const next = text.charCodeAt(i + 1);
      if (next >= 0xdc00 && next <= 0xdfff) {
        code = 0x10000 + ((code - 0xd800) << 10) + (next - 0xdc00);
        i += 1;
      }
    }
    if (code < 0x80) n += 1;
    else if (code < 0x800) n += 2;
    else if (code < 0x10000) n += 3;
    else n += 4;
  }
  return n;
}

function report(outcome, reason) {
  const detail = reason || "";
  console.log("FORREF_EVENT outcome=" + outcome + " reason=" + detail);
  if (outcome === "UNCERTAIN" || outcome === "RECOVERY_REQUIRED") {
    console.log("FORREF_RECOVERY outcome=" + outcome + " reason=" + detail);
  }
  if (outcome === "LOCAL_RECORD_VERIFIED") {
    console.log("FORREF_D1 outcome=UNCERTIFIED reason=watch-storage-not-certified");
  }
}

function idOk(value) {
  return typeof value === "string" && value.length > 0 && value.length <= 128 &&
    value === value.trim() && !/[\u0000-\u001f]/.test(value);
}

function parseEnvelope(raw) {
  let decoded;
  try {
    decoded = JSON.parse(raw);
  } catch (err) {
    return null;
  }
  if (!decoded || typeof decoded !== "object") return null;
  const origin = decoded.origin || {};
  const authority = decoded.authority || {};
  const entry = {
    matchId: decoded.matchId,
    recordId: origin.recordId,
    captureIntentId: decoded.captureIntentId,
    scoringTeamId: decoded.scoringTeamId,
    principalId: authority.principalId,
    writerDeviceId: authority.writerDeviceId,
    originSequence: origin.sequence,
  };
  if (canonicalWatchGoalV1(entry) !== raw) return null;
  if (decoded.semanticType !== "GOAL" || decoded.recordKind !== "humanDetermination") {
    return null;
  }
  if (authority.scope !== "MAIN_REFEREE" || authority.generation !== 1) return null;
  return entry;
}

export function parseGoalJournal(text) {
  if (text == null || text === "") {
    return { status: "empty", entries: [], reason: "" };
  }
  const lines = String(text).split("\n");
  const entries = [];
  let line = 0;
  while (line < lines.length) {
    if (lines[line] === "" && line === lines.length - 1) break;
    const header = lines[line];
    if (!header.startsWith("F1 ")) {
      return { status: "torn", entries: entries, reason: "torn-tail" };
    }
    const parts = header.split(" ");
    if (parts.length !== 4) {
      return { status: "corrupt", entries: entries, reason: "header" };
    }
    const sequence = Number(parts[1]);
    const byteLength = Number(parts[2]);
    const hash = parts[3];
    if (!Number.isInteger(sequence) || sequence < 1 || !Number.isInteger(byteLength)) {
      return { status: "corrupt", entries: entries, reason: "header" };
    }
    if (line + 2 >= lines.length) {
      return { status: "torn", entries: entries, reason: "torn-tail" };
    }
    const body = lines[line + 1];
    const terminator = lines[line + 2];
    if (utf8ByteLength(body) !== byteLength || terminator !== ".") {
      const atEnd = line + 2 >= lines.length - 1;
      return {
        status: atEnd ? "torn" : "corrupt",
        entries: entries,
        reason: atEnd ? "short-write" : "frame",
      };
    }
    if (sha256Hex(body) !== hash) {
      return { status: "corrupt", entries: entries, reason: "hash" };
    }
    const entry = parseEnvelope(body);
    if (!entry) {
      return { status: "corrupt", entries: entries, reason: "unsupported" };
    }
    if (entry.originSequence !== sequence) {
      return { status: "corrupt", entries: entries, reason: "sequence" };
    }
    entries.push(entry);
    line += 3;
  }
  const sequences = {};
  const recordIds = {};
  const intents = {};
  for (let i = 0; i < entries.length; i += 1) {
    const entry = entries[i];
    if (entry.originSequence !== i + 1) {
      return { status: "corrupt", entries: entries, reason: "sequence" };
    }
    if (sequences[entry.originSequence]) {
      return { status: "corrupt", entries: entries, reason: "duplicate-origin" };
    }
    sequences[entry.originSequence] = true;
    if (recordIds[entry.recordId]) {
      return { status: "corrupt", entries: entries, reason: "record-id" };
    }
    recordIds[entry.recordId] = true;
    if (intents[entry.captureIntentId]) {
      return { status: "corrupt", entries: entries, reason: "duplicate-intent" };
    }
    intents[entry.captureIntentId] = true;
  }
  return { status: entries.length === 0 ? "empty" : "ok", entries: entries, reason: "" };
}

function encodeUtf8(text) {
  const bytes = [];
  for (let i = 0; i < text.length; i += 1) {
    let code = text.charCodeAt(i);
    if (code >= 0xd800 && code <= 0xdbff && i + 1 < text.length) {
      const next = text.charCodeAt(i + 1);
      if (next >= 0xdc00 && next <= 0xdfff) {
        code = 0x10000 + ((code - 0xd800) << 10) + (next - 0xdc00);
        i += 1;
      }
    }
    if (code < 0x80) bytes.push(code);
    else if (code < 0x800) bytes.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f));
    else if (code < 0x10000) bytes.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
    else bytes.push(0xf0 | (code >> 18), 0x80 | ((code >> 12) & 0x3f), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
  }
  const buffer = new ArrayBuffer(bytes.length);
  const view = new Uint8Array(buffer);
  for (let i = 0; i < bytes.length; i += 1) view[i] = bytes[i];
  return buffer;
}

export function readStoredText(fs, path) {
  try {
    const text = fs.readFileSync({ path: path, options: { encoding: "utf8" } });
    if (text == null || text === "") return { status: "absent", text: "" };
    return { status: "ok", text: String(text) };
  } catch (err) {
    const name = String(err && err.message ? err.message : err);
    if (name.indexOf("ENOENT") >= 0 || name.indexOf("No such") >= 0 || name.indexOf("not found") >= 0) {
      return { status: "absent", text: "" };
    }
    return { status: "unreadable", text: "" };
  }
}

export function goalJournalName(matchId) {
  if (typeof matchId !== "string" || !/^[A-Za-z0-9][A-Za-z0-9._-]{0,80}$/.test(matchId)) return "";
  return "forref_watch_goal_journal_v1." + matchId + ".journal";
}

export function selectGoalJournalPath(fs, matchId) {
  const partitioned = goalJournalName(matchId);
  if (!partitioned) return { path: "", reason: "match" };
  const own = readStoredText(fs, partitioned);
  if (own.status !== "absent") return { path: partitioned, legacy: false };
  const legacy = readStoredText(fs, GOAL_JOURNAL_LEGACY_FILE);
  if (legacy.status === "absent") return { path: partitioned, legacy: false };
  if (legacy.status !== "ok") return { path: GOAL_JOURNAL_LEGACY_FILE, legacy: true };
  const parsed = parseGoalJournal(legacy.text);
  const owners = {};
  for (let i = 0; i < parsed.entries.length; i += 1) owners[parsed.entries[i].matchId] = true;
  const keys = Object.keys(owners);
  if (keys.length === 1 && keys[0] === matchId) {
    return { path: GOAL_JOURNAL_LEGACY_FILE, legacy: true };
  }
  return { path: partitioned, legacy: false };
}

function frameFor(entry) {
  const body = canonicalWatchGoalV1(entry);
  const header = "F1 " + entry.originSequence + " " + utf8ByteLength(body) + " " + sha256Hex(body);
  return header + "\n" + body + "\n.\n";
}

function result(outcome, reason, extra) {
  const body = extra || {};
  report(outcome, reason);
  return {
    ok: body.ok === true,
    outcome: outcome,
    label: body.ok === true ? LOCAL_RECORD_LABEL : "",
    reason: reason || "",
    entry: body.entry || null,
    entries: body.entries || [],
    uncertain: body.uncertain === true,
    captureIntentId: body.captureIntentId || "",
    saved: false,
    d1Certified: false,
    authoritativeCaptureAdmitted: false,
  };
}

export function createMemoryGoalStore() {
  return {
    raw: null,
    failWrite: false,
    unreadable: false,
    shortWrite: false,
    read() {
      if (this.unreadable) return { status: "unreadable" };
      if (this.raw == null || this.raw === "") return { status: "absent" };
      return { status: "ok", text: this.raw };
    },
    appendFrame(frame) {
      if (this.failWrite) return { status: "unreadable", text: this.raw || "" };
      const base = this.raw == null || this.raw === "" ? "" : this.raw;
      const chunk = this.shortWrite ? String(frame).slice(0, Math.max(0, String(frame).length - 8)) : String(frame);
      this.raw = base + chunk;
      if (this.unreadable) return { status: "unreadable", text: this.raw };
      if (this.shortWrite) return { status: "partial", text: this.raw };
      return { status: "ok", text: this.raw };
    },
  };
}

export function createFileGoalStore(fs, path) {
  return {
    read() {
      return readStoredText(fs, path);
    },
    appendFrame(frame) {
      const flags = fs.O_WRONLY | fs.O_CREAT | fs.O_APPEND;
      let fd = null;
      let partial = false;
      try {
        fd = fs.openSync({ path: path, flag: flags });
        const buffer = encodeUtf8(String(frame));
        const written = fs.writeSync({
          fd: fd,
          buffer: buffer,
          options: { offset: 0, length: buffer.byteLength, position: null },
        });
        partial = written !== buffer.byteLength;
      } catch (err) {
        partial = true;
      } finally {
        if (fd != null) {
          try {
            fs.closeSync({ fd: fd });
          } catch (err) {
            partial = true;
          }
        }
      }
      const back = readStoredText(fs, path);
      if (partial || back.status !== "ok" || !String(back.text).endsWith(frame)) {
        return { status: back.status === "unreadable" ? "unreadable" : "partial", text: back.text || "" };
      }
      return { status: "ok", text: back.text };
    },
  };
}

export function createGoalJournal(store, context) {
  let uncertainIntent = "";
  const maxEntries = context.maxEntries || MAX_GOAL_ENTRIES;

  function load() {
    const read = store.read();
    if (read.status === "unreadable") {
      return { status: "unreadable", entries: [], reason: "unreadable" };
    }
    if (read.status === "absent") {
      return { status: "empty", entries: [], reason: "" };
    }
    const parsed = parseGoalJournal(read.text);
    if (parsed.status === "torn" || parsed.status === "corrupt" || parsed.status === "unreadable") {
      return parsed;
    }
    for (let i = 0; i < parsed.entries.length; i += 1) {
      const entry = parsed.entries[i];
      if (entry.matchId !== context.matchId || entry.principalId !== context.principalId || entry.writerDeviceId !== context.writerDeviceId) {
        return { status: "corrupt", entries: parsed.entries, reason: "authority-isolation" };
      }
    }
    return parsed;
  }

  function identityFailure() {
    if (!context.localInstallationId) return "missing-installation";
    if (context.localInstallationId !== context.writerDeviceId) {
      return "installation-identity";
    }
    return "";
  }

  return {
    load: load,
    append(command) {
      const intent = command && command.captureIntentId;
      const parsed = load();
      const identity = identityFailure();
      if (identity) {
        return result("RECOVERY_REQUIRED", identity, {
          uncertain: parsed.entries.length > 0,
          captureIntentId: intent || "",
          entries: parsed.entries,
        });
      }
      if (parsed.status === "torn" || parsed.status === "corrupt" || parsed.status === "unreadable") {
        return result("RECOVERY_REQUIRED", parsed.reason || parsed.status, {
          uncertain: true,
          captureIntentId: uncertainIntent || intent || "",
          entries: parsed.entries,
        });
      }
      if (uncertainIntent && intent !== uncertainIntent) {
        return result("RECOVERY_REQUIRED", "reconciliation", {
          uncertain: true,
          captureIntentId: uncertainIntent,
          entries: parsed.entries,
        });
      }
      if (!context.authorityActivated) {
        return result("REFUSED", "authority-not-activated", { entries: parsed.entries });
      }
      if (!idOk(command.captureIntentId) || !idOk(command.recordId)) {
        return result("REFUSED", "identity", { entries: parsed.entries });
      }
      const team = command.scoringTeamId;
      if (team === "HOME" || team === "AWAY" || (team !== context.homeTeamId && team !== context.awayTeamId)) {
        return result("REFUSED", "scoringTeamId", { entries: parsed.entries });
      }
      const existing = parsed.entries.find((entry) => entry.captureIntentId === command.captureIntentId);
      if (existing) {
        if (existing.scoringTeamId !== team || existing.recordId !== command.recordId) {
          return result("REFUSED", "intent-conflict", { entries: parsed.entries, captureIntentId: command.captureIntentId });
        }
        uncertainIntent = "";
        return result("LOCAL_RECORD_VERIFIED", "idempotent", {
          ok: true,
          entry: existing,
          entries: parsed.entries,
          captureIntentId: command.captureIntentId,
        });
      }
      if (parsed.entries.some((entry) => entry.recordId === command.recordId)) {
        return result("REFUSED", "record-id", { entries: parsed.entries });
      }
      if (parsed.entries.length >= maxEntries) {
        return result("REFUSED", "capacity", { entries: parsed.entries });
      }
      const entry = {
        matchId: context.matchId,
        recordId: command.recordId,
        captureIntentId: command.captureIntentId,
        scoringTeamId: team,
        principalId: context.principalId,
        writerDeviceId: context.writerDeviceId,
        originSequence: parsed.entries.length + 1,
      };
      if (typeof store.appendFrame !== "function") {
        return result("RECOVERY_REQUIRED", "append", { uncertain: true, captureIntentId: entry.captureIntentId, entries: parsed.entries });
      }
      const wrote = store.appendFrame(frameFor(entry));
      const after = load();
      const found = after.entries.find((item) => item.captureIntentId === entry.captureIntentId && item.recordId === entry.recordId && item.scoringTeamId === entry.scoringTeamId);
      if (found && after.status === "ok") {
        uncertainIntent = "";
        return result("LOCAL_RECORD_VERIFIED", "", {
          ok: true,
          entry: found,
          entries: after.entries,
          captureIntentId: entry.captureIntentId,
        });
      }
      uncertainIntent = entry.captureIntentId;
      const reason = after.reason || (wrote.status !== "ok" ? "read-after-write" : "read-after-write");
      return result("UNCERTAIN", reason, {
        uncertain: true,
        captureIntentId: entry.captureIntentId,
        entries: after.entries,
      });
    },
  };
}
