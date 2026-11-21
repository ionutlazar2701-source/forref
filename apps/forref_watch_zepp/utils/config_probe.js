// Probe A configuration exchange.
// The body is a fixed side-service fixture. It is not a Match Record,
// not the phone payload, and not the match clock.

export const PROBE_FILE = "forref_probe_a_config.json";
export const GET_CONFIGURATION = "GET_CONFIGURATION";
export const CONFIGURATION_STORED = "CONFIGURATION_STORED";

const FIELDS = [
  "payloadVersion",
  "probe",
  "matchId",
  "homeTeamName",
  "awayTeamName",
  "source",
];

export const STATIC_CONFIGURATION = {
  payloadVersion: 1,
  probe: "A",
  matchId: "probe-a-static",
  homeTeamName: "North",
  awayTeamName: "South",
  source: "side-service-static",
};

export function canonicalConfiguration(payload) {
  return JSON.stringify({
    payloadVersion: payload.payloadVersion,
    probe: payload.probe,
    matchId: payload.matchId,
    homeTeamName: payload.homeTeamName,
    awayTeamName: payload.awayTeamName,
    source: payload.source,
  });
}

export function contentHash(payload) {
  const text = canonicalConfiguration(payload);
  let hash = 2166136261;
  for (let i = 0; i < text.length; i += 1) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(16).padStart(8, "0");
}

function allowedShape(payload) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return false;
  }
  const keys = Object.keys(payload);
  if (keys.length !== FIELDS.length) {
    return false;
  }
  return FIELDS.every((field) => keys.includes(field));
}

export function sideAnswer(request) {
  const method = request && request.method;
  if (method === GET_CONFIGURATION) {
    const payload = STATIC_CONFIGURATION;
    return {
      error: null,
      data: {
        disposition: "payload",
        payload: payload,
        contentHash: contentHash(payload),
      },
    };
  }
  if (method === CONFIGURATION_STORED) {
    const params = (request && request.params) || {};
    const expected = contentHash(STATIC_CONFIGURATION);
    if (
      params.payloadVersion !== STATIC_CONFIGURATION.payloadVersion ||
      params.matchId !== STATIC_CONFIGURATION.matchId ||
      params.contentHash !== expected
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
}

export function acceptPayload(message) {
  if (!message || message.disposition !== "payload" || !allowedShape(message.payload)) {
    return { ok: false, reason: "shape" };
  }
  if (message.payload.payloadVersion !== 1 || message.payload.probe !== "A") {
    return { ok: false, reason: "version" };
  }
  if (message.payload.source !== "side-service-static") {
    return { ok: false, reason: "source" };
  }
  if (message.contentHash !== contentHash(message.payload)) {
    return { ok: false, reason: "hash" };
  }
  return {
    ok: true,
    record: {
      payloadVersion: message.payload.payloadVersion,
      probe: message.payload.probe,
      matchId: message.payload.matchId,
      homeTeamName: message.payload.homeTeamName,
      awayTeamName: message.payload.awayTeamName,
      source: message.payload.source,
      contentHash: message.contentHash,
    },
  };
}

export function storeRecord(io, record) {
  const text = canonicalConfiguration(record);
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

export function receiptRequest(record) {
  return {
    method: CONFIGURATION_STORED,
    params: {
      payloadVersion: record.payloadVersion,
      matchId: record.matchId,
      contentHash: record.contentHash,
    },
  };
}
