// Phone configuration over the debug loopback.
// The body is the persisted MatchConfigurationPayload. It is not a Match
// Record, not the match clock, and not the Probe A static fixture.

export const LOCAL_FILE = "forref_local_bridge_config.json";
export const LOCAL_BRIDGE_URL = "http://127.0.0.1:47221/match-configuration";
export const GET_LOCAL_CONFIGURATION = "GET_LOCAL_CONFIGURATION";
export const LOCAL_CONFIGURATION_STORED = "LOCAL_CONFIGURATION_STORED";

const FIELDS = [
  "payloadVersion",
  "matchId",
  "updatedAt",
  "date",
  "competition",
  "venue",
  "homeTeamId",
  "homeTeamName",
  "awayTeamId",
  "awayTeamName",
  "halfDurationSeconds",
  "extraTimeEnabled",
  "extraTimeHalfDurationSeconds",
  "referee",
  "assistantReferee1",
  "assistantReferee2",
  "fourthOfficial",
];

const FORBIDDEN = ["score", "events", "status", "sync", "history", "probe", "source"];

export function isLocalMethod(method) {
  return method === GET_LOCAL_CONFIGURATION || method === LOCAL_CONFIGURATION_STORED;
}

export function canonicalPhonePayload(payload) {
  const out = {};
  for (let i = 0; i < FIELDS.length; i += 1) {
    const field = FIELDS[i];
    const value = payload[field];
    out[field] = value === undefined ? null : value;
  }
  return JSON.stringify(out);
}

export function contentHash(payload) {
  const text = canonicalPhonePayload(payload);
  let hash = 2166136261;
  for (let i = 0; i < text.length; i += 1) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(16).padStart(8, "0");
}

function optionalText(value) {
  return value === null || typeof value === "string";
}

export function acceptPhonePayload(payload) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return { ok: false, reason: "shape" };
  }
  for (let i = 0; i < FORBIDDEN.length; i += 1) {
    if (Object.hasOwn(payload, FORBIDDEN[i])) {
      return { ok: false, reason: "forbidden" };
    }
  }
  if (payload.payloadVersion !== 1) {
    return { ok: false, reason: "version" };
  }
  if (typeof payload.matchId !== "string" || payload.matchId.trim() === "") {
    return { ok: false, reason: "match" };
  }
  if (payload.matchId === "probe-a-static") {
    return { ok: false, reason: "fixture" };
  }
  if (typeof payload.updatedAt !== "string" || typeof payload.date !== "string") {
    return { ok: false, reason: "identity" };
  }
  if (typeof payload.homeTeamId !== "string" || payload.homeTeamId.trim() === "") {
    return { ok: false, reason: "home" };
  }
  if (typeof payload.awayTeamId !== "string" || payload.awayTeamId.trim() === "") {
    return { ok: false, reason: "away" };
  }
  if (typeof payload.halfDurationSeconds !== "number") {
    return { ok: false, reason: "duration" };
  }
  if (typeof payload.extraTimeEnabled !== "boolean") {
    return { ok: false, reason: "extra" };
  }
  if (typeof payload.extraTimeHalfDurationSeconds !== "number") {
    return { ok: false, reason: "extra-duration" };
  }
  if (
    !optionalText(payload.competition) ||
    !optionalText(payload.venue) ||
    !optionalText(payload.homeTeamName) ||
    !optionalText(payload.awayTeamName) ||
    !optionalText(payload.referee) ||
    !optionalText(payload.assistantReferee1) ||
    !optionalText(payload.assistantReferee2) ||
    !optionalText(payload.fourthOfficial)
  ) {
    return { ok: false, reason: "text" };
  }
  const record = JSON.parse(canonicalPhonePayload(payload));
  record.contentHash = contentHash(record);
  return { ok: true, record: record };
}

export function acceptPhoneMessage(message) {
  if (!message || message.disposition !== "payload") {
    return { ok: false, reason: "unavailable" };
  }
  const accepted = acceptPhonePayload(message.payload);
  if (!accepted.ok) {
    return accepted;
  }
  if (message.contentHash !== accepted.record.contentHash) {
    return { ok: false, reason: "hash" };
  }
  return accepted;
}

export function teamLabel(value, unset) {
  if (typeof value !== "string") {
    return unset;
  }
  const trimmed = value.trim();
  return trimmed ? trimmed : unset;
}

export function storeRecord(io, record) {
  const text = canonicalPhonePayload(record);
  let written = "";
  try {
    io.write(text);
    written = io.read();
  } catch (err) {
    return { stored: false, reason: "io" };
  }
  if (written !== text) {
    return { stored: false, reason: "readback" };
  }
  return { stored: true, text: text };
}

export function readStored(io) {
  let text = "";
  try {
    text = io.read();
  } catch (err) {
    return { ok: false, reason: "io" };
  }
  if (!text) {
    return { ok: false, reason: "empty" };
  }
  try {
    return acceptPhonePayload(JSON.parse(text));
  } catch (err) {
    return { ok: false, reason: "shape" };
  }
}

export function applyFetch(message, io) {
  const accepted = acceptPhoneMessage(message);
  if (!accepted.ok) {
    const saved = readStored(io);
    return {
      stored: false,
      detail: accepted.reason,
      record: null,
      names: saved.ok
        ? { home: saved.record.homeTeamName, away: saved.record.awayTeamName }
        : null,
      savedCopy: saved.ok,
    };
  }
  const written = storeRecord(io, accepted.record);
  if (!written.stored) {
    return {
      stored: false,
      detail: written.reason,
      record: null,
      names: null,
      savedCopy: false,
    };
  }
  return {
    stored: true,
    detail: accepted.record.contentHash,
    record: accepted.record,
    names: {
      home: accepted.record.homeTeamName,
      away: accepted.record.awayTeamName,
    },
    savedCopy: false,
  };
}

export function receiptRequest(record) {
  return {
    method: LOCAL_CONFIGURATION_STORED,
    params: {
      payloadVersion: record.payloadVersion,
      matchId: record.matchId,
      contentHash: record.contentHash,
    },
  };
}

async function responseText(response) {
  if (!response) {
    return "";
  }
  if (typeof response.text === "function") {
    return response.text();
  }
  if (response.body && typeof response.body.text === "string") {
    return response.body.text;
  }
  if (response.body && typeof response.body.text === "function") {
    return response.body.text();
  }
  if (typeof response.body === "string") {
    return response.body;
  }
  return "";
}

async function messageFromResponse(response) {
  const status = response && typeof response.status === "number" ? response.status : 0;
  if (status !== 200) {
    return { disposition: "unavailable" };
  }
  let payload;
  try {
    payload = JSON.parse(await responseText(response));
  } catch (err) {
    return { disposition: "unavailable" };
  }
  const accepted = acceptPhonePayload(payload);
  if (!accepted.ok) {
    return { disposition: "unavailable" };
  }
  return {
    disposition: "payload",
    payload: JSON.parse(canonicalPhonePayload(accepted.record)),
    contentHash: accepted.record.contentHash,
  };
}

export function createLocalBridge() {
  let last = null;
  return {
    async answer(request, fetchImpl) {
      const method = request && request.method;
      if (method === GET_LOCAL_CONFIGURATION) {
        try {
          const response = await fetchImpl(LOCAL_BRIDGE_URL);
          const data = await messageFromResponse(response);
          last = data.disposition === "payload" ? data : last;
          return { error: null, data: data };
        } catch (err) {
          return { error: null, data: { disposition: "unavailable" } };
        }
      }
      if (method === LOCAL_CONFIGURATION_STORED) {
        const params = (request && request.params) || {};
        if (
          !last ||
          params.payloadVersion !== 1 ||
          params.matchId !== last.payload.matchId ||
          params.contentHash !== last.contentHash
        ) {
          return { error: "reject", data: { disposition: "rejected" } };
        }
        return {
          error: null,
          data: {
            disposition: "recorded",
            payloadVersion: params.payloadVersion,
            matchId: params.matchId,
            contentHash: params.contentHash,
          },
        };
      }
      return { error: "unknown-method", data: { disposition: "rejected" } };
    },
  };
}
