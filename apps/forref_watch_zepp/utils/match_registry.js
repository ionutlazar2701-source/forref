export const MATCH_REGISTRY_FILE = "forref_watch_match_registry_v1.txt";

function clean(value) {
  return typeof value === "string" ? value : "";
}

function entryFrom(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
  const matchId = clean(raw.matchId);
  const contentHash = clean(raw.contentHash);
  const writerDeviceId = clean(raw.writerDeviceId);
  const homeName = clean(raw.homeName);
  const awayName = clean(raw.awayName);
  const homeTeamId = clean(raw.homeTeamId);
  const awayTeamId = clean(raw.awayTeamId);
  const halfDurationMs = raw.halfDurationMs;
  if (!matchId || !/^[0-9a-f]{64}$/.test(contentHash) || !writerDeviceId) return null;
  if (!homeName || !awayName || !homeTeamId || !awayTeamId) return null;
  if (homeTeamId === awayTeamId) return null;
  if (typeof halfDurationMs !== "number" || !Number.isInteger(halfDurationMs) || halfDurationMs <= 0) return null;
  if (raw.generation !== 1 || raw.status !== "verified") return null;
  return {
    matchId: matchId,
    homeTeamId: homeTeamId,
    homeName: homeName,
    awayTeamId: awayTeamId,
    awayName: awayName,
    halfDurationMs: halfDurationMs,
    contentHash: contentHash,
    writerDeviceId: writerDeviceId,
    generation: 1,
    status: "verified",
  };
}

export function readMatchRegistry(store) {
  const read = store && store.read ? store.read() : null;
  if (!read || read.status === "unreadable") return { ok: false, reason: "registry-unreadable", matches: [] };
  if (read.status === "absent" || !read.text) return { ok: true, reason: "", matches: [] };
  let parsed;
  try {
    parsed = JSON.parse(String(read.text));
  } catch (err) {
    return { ok: false, reason: "registry-corrupt", matches: [] };
  }
  if (!parsed || parsed.v !== 1 || !Array.isArray(parsed.matches)) {
    return { ok: false, reason: "registry-corrupt", matches: [] };
  }
  const matches = [];
  for (let i = 0; i < parsed.matches.length; i += 1) {
    const entry = entryFrom(parsed.matches[i]);
    if (!entry) return { ok: false, reason: "registry-corrupt", matches: [] };
    matches.push(entry);
  }
  return { ok: true, reason: "", matches: matches };
}

function same(left, right) {
  return left.matchId === right.matchId &&
    left.homeTeamId === right.homeTeamId &&
    left.homeName === right.homeName &&
    left.awayTeamId === right.awayTeamId &&
    left.awayName === right.awayName &&
    left.halfDurationMs === right.halfDurationMs &&
    left.contentHash === right.contentHash &&
    left.writerDeviceId === right.writerDeviceId &&
    left.generation === 1 &&
    left.status === "verified";
}

export function commitVerified(store, entry) {
  const current = readMatchRegistry(store);
  if (!current.ok && current.reason !== "") return current;
  const record = entryFrom(entry);
  if (!record) return { ok: false, reason: "registry", matches: current.matches, wrote: false };
  const matches = current.matches.slice();
  const index = matches.findIndex((item) => item.matchId === record.matchId);
  if (index >= 0) {
    if (matches[index].contentHash !== record.contentHash || matches[index].writerDeviceId !== record.writerDeviceId) {
      return { ok: false, reason: "conflict", matches: current.matches, wrote: false };
    }
    if (same(matches[index], record)) {
      return { ok: true, reason: "replay", matches: matches, wrote: false };
    }
    matches[index] = record;
  } else {
    matches.push(record);
  }
  matches.sort((left, right) => left.matchId < right.matchId ? -1 : left.matchId > right.matchId ? 1 : 0);
  const body = JSON.stringify({ v: 1, matches: matches });
  const wrote = store.write(body);
  const back = store.read();
  if (!wrote || wrote.status !== "ok" || !back || back.status !== "ok" || String(back.text).trim() !== body) {
    return { ok: false, reason: "registry-write", matches: current.matches, wrote: false };
  }
  return { ok: true, reason: "verified", matches: matches, wrote: true };
}

export function transferRootName(matchId) {
  if (typeof matchId !== "string" || !/^[A-Za-z0-9-]{8,80}$/.test(matchId)) return "";
  return "forref_watch_transfer_v1." + matchId + ".root";
}

export function transferAdmissionName(matchId) {
  const root = transferRootName(matchId);
  return root ? root.replace(/\.root$/, ".admission") : "";
}
