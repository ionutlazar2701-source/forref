import { parseWatchProvisionV1 } from "./watch_provision.js";

export const PROVISION_BRIDGE_URL = "http://127.0.0.1:47221/watch-provision/v1";
export const PROVISION_CORRELATION_FILE = "forref_watch_provision_correlation_v1.txt";

export const GET_WATCH_PROVISION_V1 = "GET_WATCH_PROVISION_V1";
export const SUBMIT_WATCH_LOCK_V1 = "SUBMIT_WATCH_LOCK_V1";
export const REPORT_WATCH_ACTIVATED_V1 = "REPORT_WATCH_ACTIVATED_V1";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export function isProvisionMethod(method) {
  return method === GET_WATCH_PROVISION_V1 ||
    method === SUBMIT_WATCH_LOCK_V1 ||
    method === REPORT_WATCH_ACTIVATED_V1;
}

function uuid() {
  const bytes = new Array(16);
  for (let i = 0; i < 16; i += 1) bytes[i] = Math.floor(Math.random() * 256);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.map((value) => value.toString(16).padStart(2, "0")).join("");
  return hex.slice(0, 8) + "-" + hex.slice(8, 12) + "-" + hex.slice(12, 16) + "-" + hex.slice(16, 20) + "-" + hex.slice(20);
}

function correlationText(installationId, requestId) {
  return '{"installationId":' + JSON.stringify(installationId) + ',"requestId":' + JSON.stringify(requestId) + "}";
}

export function loadCorrelation(store, installationId, allocate) {
  const read = store.read();
  if (!read || read.status === "unreadable") {
    return { ok: false, reason: "correlation-unreadable", requestId: "" };
  }
  if (read.status === "ok" && read.text) {
    let parsed;
    try {
      parsed = JSON.parse(read.text);
    } catch (err) {
      return { ok: false, reason: "correlation-corrupt", requestId: "" };
    }
    const text = correlationText(parsed.installationId, parsed.requestId);
    if (text !== String(read.text).trim() || !UUID.test(parsed.requestId)) {
      return { ok: false, reason: "correlation-corrupt", requestId: "" };
    }
    if (parsed.installationId !== installationId) {
      return { ok: false, reason: "correlation-conflict", requestId: parsed.requestId };
    }
    return { ok: true, reason: "", requestId: parsed.requestId };
  }
  const requestId = allocate ? allocate() : uuid();
  if (!UUID.test(requestId)) return { ok: false, reason: "correlation", requestId: "" };
  const body = correlationText(installationId, requestId);
  const wrote = store.write(body);
  const back = store.read();
  if (!wrote || wrote.status !== "ok" || !back || back.status !== "ok" || String(back.text).trim() !== body) {
    return { ok: false, reason: "correlation-write", requestId: "" };
  }
  return { ok: true, reason: "", requestId: requestId };
}

export function sideFetchBody(method, params) {
  const source = params || {};
  if (!UUID.test(source.installationId || "") || !UUID.test(source.requestId || "") || source.generation !== 1) {
    return null;
  }
  if (method === GET_WATCH_PROVISION_V1) {
    return {
      operation: "pending",
      installationId: source.installationId,
      requestId: source.requestId,
      generation: 1,
    };
  }
  if (typeof source.matchId !== "string" || source.matchId === "" || typeof source.contentHash !== "string") {
    return null;
  }
  const body = {
    installationId: source.installationId,
    requestId: source.requestId,
    generation: 1,
    matchId: source.matchId,
    contentHash: source.contentHash,
    writerDeviceId: source.installationId,
  };
  if (method === SUBMIT_WATCH_LOCK_V1) {
    body.operation = "lock";
    body.readBack = source.readBack === true;
    body.type = "WATCH_PROVISION_VERIFIED_V1";
    return body;
  }
  if (method === REPORT_WATCH_ACTIVATED_V1) {
    body.operation = "activation";
    body.readBack = source.readBack === true;
    body.type = "WATCH_ACTIVATED_V1";
    return body;
  }
  return null;
}

export function acceptPrepared(body, installationId, requestId) {
  if (!body || typeof body !== "object") return { ok: false, reason: "unavailable" };
  if (body.disposition !== "prepared") return { ok: false, reason: body.disposition || body.reason || "unavailable" };
  if (Object.prototype.hasOwnProperty.call(body, "payloadVersion")) return { ok: false, reason: "payload" };
  if (body.schema !== "forref.watch-provision.v1") return { ok: false, reason: "schema" };
  if (body.installationId !== installationId || body.requestId !== requestId || body.generation !== 1) {
    return { ok: false, reason: "binding" };
  }
  if (typeof body.canonical !== "string") return { ok: false, reason: "canonical" };
  const parsed = parseWatchProvisionV1(body.canonical);
  const document = parsed.document;
  if (!document) return { ok: false, reason: parsed.reason || "canonical" };
  if (document.writerDeviceId !== installationId || document.matchId !== body.matchId || document.contentHash !== body.contentHash) {
    return { ok: false, reason: "binding" };
  }
  return {
    ok: true,
    reason: "",
    canonical: document.canonical,
    matchId: document.matchId,
    contentHash: document.contentHash,
    homeName: document.homeName,
    awayName: document.awayName,
  };
}

export function applyPrepared(admission, body, installationId, requestId) {
  const prepared = acceptPrepared(body, installationId, requestId);
  if (!prepared.ok) return prepared;
  const received = admission.receive(prepared.canonical, installationId, false);
  const stored = admission.loadDurable(installationId, false);
  if (received.contentHash !== prepared.contentHash || stored.canonical !== prepared.canonical || stored.contentHash !== prepared.contentHash) {
    return { ok: false, reason: received.reason || stored.reason || "readback" };
  }
  if (stored.state !== "WATCH_CONFIG_VERIFIED" && stored.state !== "WATCH_ACTIVATED") {
    return { ok: false, reason: received.reason || stored.state || "readback" };
  }
  return {
    ok: true,
    reason: "",
    stage: stored.state === "WATCH_ACTIVATED" ? "activated" : "verified",
    matchId: prepared.matchId,
    contentHash: prepared.contentHash,
    homeName: prepared.homeName,
    awayName: prepared.awayName,
    installationId: installationId,
    requestId: requestId,
    receipt: {
      type: "WATCH_PROVISION_VERIFIED_V1",
      matchId: prepared.matchId,
      contentHash: prepared.contentHash,
      installationId: installationId,
      writerDeviceId: installationId,
      generation: 1,
      readBack: true,
      requestId: requestId,
    },
  };
}

export function acceptLock(body, receipt) {
  if (!body || typeof body !== "object") return { ok: false, reason: "unavailable", durable: false };
  if (body.durable !== true) return { ok: false, reason: body.reason || "durable", durable: false };
  if (body.disposition !== "locked") return { ok: false, reason: body.disposition || "lock", durable: false };
  if (!receipt || body.matchId !== receipt.matchId || body.contentHash !== receipt.contentHash || body.requestId !== receipt.requestId) {
    return { ok: false, reason: "binding", durable: false };
  }
  if (body.installationId !== receipt.installationId || body.generation !== 1) {
    return { ok: false, reason: "binding", durable: false };
  }
  return {
    ok: true,
    reason: "",
    durable: true,
    lockReceipt: {
      contentHash: receipt.contentHash,
      writerDeviceId: receipt.installationId,
      generation: 1,
      durable: true,
    },
  };
}

export function applyActivation(admission, body, receipt) {
  const lock = acceptLock(body, receipt);
  if (!lock.ok) return lock;
  const activated = admission.activate(receipt.installationId, lock.lockReceipt);
  const stored = admission.loadDurable(receipt.installationId, false);
  if (activated.state !== "WATCH_ACTIVATED" || stored.state !== "WATCH_ACTIVATED" || stored.canonical == null || stored.contentHash !== receipt.contentHash) {
    return { ok: false, reason: activated.reason || stored.reason || "activation-readback", durable: true };
  }
  return {
    ok: true,
    reason: "",
    stage: "activated",
    durable: true,
    report: {
      type: "WATCH_ACTIVATED_V1",
      matchId: receipt.matchId,
      contentHash: receipt.contentHash,
      installationId: receipt.installationId,
      writerDeviceId: receipt.installationId,
      generation: 1,
      readBack: true,
      requestId: receipt.requestId,
    },
  };
}

export async function runHandshake(deps) {
  const installation = deps.loadInstallation();
  if (!installation.ok) {
    return { ok: false, stage: "identity", reason: installation.reason || "installation", transport: "" };
  }
  const correlation = loadCorrelation(deps.requestStore, installation.id, deps.allocate);
  if (!correlation.ok) {
    return { ok: false, stage: "identity", reason: correlation.reason, installationId: installation.id, transport: "" };
  }
  let pending;
  try {
    pending = await deps.request({
      method: GET_WATCH_PROVISION_V1,
      params: { installationId: installation.id, requestId: correlation.requestId, generation: 1 },
    });
  } catch (err) {
    pending = { disposition: "unavailable" };
  }
  const verified = applyPrepared(deps.admission, pending, installation.id, correlation.requestId);
  if (!verified.ok) {
    return {
      ok: false,
      stage: pending && pending.disposition === "prepared" ? "prepared" : "transport",
      reason: verified.reason,
      installationId: installation.id,
      requestId: correlation.requestId,
      transport: pending && pending.disposition || "unavailable",
    };
  }
  let locked;
  try {
    locked = await deps.request({ method: SUBMIT_WATCH_LOCK_V1, params: verified.receipt });
  } catch (err) {
    locked = { disposition: "unavailable", durable: false };
  }
  const activation = applyActivation(deps.admission, locked, verified.receipt);
  if (!activation.ok) {
    return {
      ok: false,
      stage: activation.durable ? "lock" : "verified",
      reason: activation.reason,
      installationId: installation.id,
      requestId: correlation.requestId,
      matchId: verified.matchId,
      contentHash: verified.contentHash,
      homeName: verified.homeName,
      awayName: verified.awayName,
      transport: locked && locked.disposition || "unavailable",
      durable: activation.durable === true,
    };
  }
  let reported;
  try {
    reported = await deps.request({ method: REPORT_WATCH_ACTIVATED_V1, params: activation.report });
  } catch (err) {
    reported = { disposition: "unavailable" };
  }
  const recorded = reported && reported.disposition === "recorded";
  return {
    ok: recorded,
    stage: recorded ? "activated" : "report",
    reason: recorded ? "" : (reported && reported.reason) || "report",
    installationId: installation.id,
    requestId: correlation.requestId,
    matchId: verified.matchId,
    contentHash: verified.contentHash,
    homeName: verified.homeName,
    awayName: verified.awayName,
    transport: reported && reported.disposition || "unavailable",
    durable: true,
  };
}
