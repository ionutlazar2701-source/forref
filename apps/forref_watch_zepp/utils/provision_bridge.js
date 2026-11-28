import { BUILD_CODE, BUILD_NAME, BUILD_REV, BUILD_VERSION } from "./build_stamp.js";
import { sanitizeWitness } from "./identity_witness.js";
import { parseWatchProvisionV1 } from "./watch_provision.js";

export const PROVISION_BRIDGE_URL = "http://127.0.0.1:47221/watch-provision/v1";
export const PROVISION_CORRELATION_FILE = "forref_watch_provision_correlation_v1.txt";
export const ENROLL_CORRELATION_FILE = "forref_watch_enroll_correlation_v1.txt";
export const ENROLL_ROOT_FILE = "forref_watch_enroll_v1.root";
export const ENROLL_ADMISSION_FILE = "forref_watch_enroll_v1.admission";
export const PAIR_CORRELATION_FILE = "forref_watch_pair_correlation_v1.txt";
export const PAIR_ROOT_FILE = "forref_watch_pair_v1.root";
export const PAIR_ADMISSION_FILE = "forref_watch_pair_v1.admission";

export const GET_WATCH_PROVISION_V1 = "GET_WATCH_PROVISION_V1";
export const SUBMIT_WATCH_LOCK_V1 = "SUBMIT_WATCH_LOCK_V1";
export const REPORT_WATCH_ACTIVATED_V1 = "REPORT_WATCH_ACTIVATED_V1";
export const GET_SIDE_BUILD_V1 = "GET_SIDE_BUILD_V1";
export const PROBE_BRIDGE_V1 = "PROBE_BRIDGE_V1";
export const PROBE_BODY = "{\"operation\":\"probe\"}";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export function isProvisionMethod(method) {
  return method === GET_WATCH_PROVISION_V1 ||
    method === SUBMIT_WATCH_LOCK_V1 ||
    method === REPORT_WATCH_ACTIVATED_V1;
}

// COM-004R keeps lock and activation off while the side build is diagnosed.
// A caller that still asks is refused before fetch.
export function blockedDuringPrepare(method) {
  return method === SUBMIT_WATCH_LOCK_V1 || method === REPORT_WATCH_ACTIVATED_V1;
}

function uuid() {
  const bytes = new Array(16);
  for (let i = 0; i < 16; i += 1) bytes[i] = Math.floor(Math.random() * 256);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.map((value) => value.toString(16).padStart(2, "0")).join("");
  return hex.slice(0, 8) + "-" + hex.slice(8, 12) + "-" + hex.slice(12, 16) + "-" + hex.slice(16, 20) + "-" + hex.slice(20);
}

const PHASES = { pending: 1, verified: 1, activated: 1, reported: 1 };

export function correlationText(record) {
  let text = '{"installationId":' + JSON.stringify(record.installationId) +
    ',"requestId":' + JSON.stringify(record.requestId) +
    ',"generation":1,"phase":' + JSON.stringify(record.phase || "pending");
  if (record.matchId) {
    text += ',"matchId":' + JSON.stringify(record.matchId) +
      ',"contentHash":' + JSON.stringify(record.contentHash);
  }
  return text + "}";
}

function legacyCorrelationText(installationId, requestId) {
  return '{"installationId":' + JSON.stringify(installationId) + ',"requestId":' + JSON.stringify(requestId) + "}";
}

function correlationFromParsed(parsed) {
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null;
  if (!UUID.test(parsed.requestId || "") || typeof parsed.installationId !== "string" || !UUID.test(parsed.installationId)) {
    return null;
  }
  const phase = parsed.phase || "pending";
  if (!PHASES[phase] || (parsed.generation != null && parsed.generation !== 1)) return null;
  const record = {
    installationId: parsed.installationId,
    requestId: parsed.requestId,
    generation: 1,
    phase: phase,
    matchId: "",
    contentHash: "",
  };
  if (parsed.matchId != null || parsed.contentHash != null) {
    if (typeof parsed.matchId !== "string" || parsed.matchId === "" || typeof parsed.contentHash !== "string" || !/^[0-9a-f]{64}$/.test(parsed.contentHash)) {
      return null;
    }
    record.matchId = parsed.matchId;
    record.contentHash = parsed.contentHash;
  }
  return record;
}

export function readCorrelation(store) {
  const read = store && store.read ? store.read() : null;
  if (!read || read.status === "unreadable") {
    return { ok: false, present: false, reason: "correlation-unreadable", requestId: "", generation: 1, phase: "", matchId: "", contentHash: "" };
  }
  if (read.status !== "ok" || !read.text) {
    return { ok: true, present: false, reason: "absent", requestId: "", generation: 1, phase: "absent", matchId: "", contentHash: "" };
  }
  let parsed;
  try {
    parsed = JSON.parse(read.text);
  } catch (err) {
    return { ok: false, present: false, reason: "correlation-corrupt", requestId: "", generation: 1, phase: "", matchId: "", contentHash: "" };
  }
  const record = correlationFromParsed(parsed);
  const trimmed = String(read.text).trim();
  const current = record ? correlationText(record) : "";
  const legacy = parsed && typeof parsed === "object" ? legacyCorrelationText(parsed.installationId, parsed.requestId) : "";
  if (!record || (trimmed !== current && trimmed !== legacy)) {
    return { ok: false, present: false, reason: "correlation-corrupt", requestId: "", generation: 1, phase: "", matchId: "", contentHash: "" };
  }
  return {
    ok: true,
    present: true,
    reason: "",
    requestId: record.requestId,
    generation: 1,
    phase: record.phase,
    matchId: record.matchId,
    contentHash: record.contentHash,
    installationId: record.installationId,
  };
}

// Reads the stored correlation and the watch admission. It does not allocate
// a request id and does not write either file.
export function readProvisionEvidence(installation, correlationStore, admission) {
  const installationId = installation && installation.ok ? installation.id : "";
  const before = correlationStore && correlationStore.read ? correlationStore.read() : null;
  const correlation = readCorrelation(correlationStore);
  const stored = installationId && admission ? admission.loadDurable(installationId, false) : null;
  const after = correlationStore && correlationStore.read ? correlationStore.read() : null;
  const sameText = !before || !after || before.status === after.status && before.text === after.text;
  const hash = correlation.contentHash || "";
  const storedHash = stored && stored.contentHash ? stored.contentHash : "";
  const verified = stored && (stored.state === "WATCH_CONFIG_VERIFIED" || stored.state === "WATCH_ACTIVATED");
  const readback = !!(verified && hash && storedHash === hash);
  const canonical = readback ? "accepted" : storedHash ? "rejected" : "absent";
  const phase = correlation.phase || "absent";
  const lock = phase === "activated" || phase === "reported" ? 1 : 0;
  const activation = phase === "reported" ? 1 : 0;
  const fields = {
    tx: "evidence",
    installation: installationId,
    request: correlation.requestId,
    match: correlation.matchId,
    hash: hash,
    generation: 1,
    phase: phase,
    canonical: canonical,
    readback: readback ? 1 : 0,
    durable: readback ? 1 : 0,
    lock: lock,
    activation: activation,
    wrote: sameText ? 0 : 1,
  };
  return Object.assign({ line: evidenceLine(fields), ok: correlation.ok && sameText }, fields);
}

function evidenceLine(fields) {
  const parts = ["FORREF_PROVISION"];
  const keys = Object.keys(fields);
  for (let i = 0; i < keys.length; i += 1) {
    const value = fields[keys[i]];
    if (value == null || value === "") continue;
    parts.push(keys[i] + "=" + value);
  }
  return parts.join(" ");
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
    const record = correlationFromParsed(parsed);
    const trimmed = String(read.text).trim();
    const current = record ? correlationText(record) : "";
    const legacy = parsed && typeof parsed === "object" ? legacyCorrelationText(parsed.installationId, parsed.requestId) : "";
    if (!record || (trimmed !== current && trimmed !== legacy)) {
      return { ok: false, reason: "correlation-corrupt", requestId: "" };
    }
    if (record.installationId !== installationId) {
      return { ok: false, reason: "correlation-conflict", requestId: record.requestId };
    }
    return { ok: true, reason: "", requestId: record.requestId, generation: 1, phase: record.phase, matchId: record.matchId, contentHash: record.contentHash };
  }
  const requestId = allocate ? allocate() : uuid();
  if (!UUID.test(requestId)) return { ok: false, reason: "correlation", requestId: "" };
  return saveCorrelation(store, {
    installationId: installationId,
    requestId: requestId,
    generation: 1,
    phase: "pending",
  });
}

export function saveCorrelation(store, record) {
  const body = correlationText(record);
  const wrote = store.write(body);
  const back = store.read();
  if (!wrote || wrote.status !== "ok" || !back || back.status !== "ok" || String(back.text).trim() !== body) {
    return { ok: false, reason: "correlation-write", requestId: record.requestId || "", generation: 1, phase: record.phase || "", matchId: record.matchId || "", contentHash: record.contentHash || "" };
  }
  return {
    ok: true,
    reason: "",
    requestId: record.requestId,
    generation: 1,
    phase: record.phase || "pending",
    matchId: record.matchId || "",
    contentHash: record.contentHash || "",
  };
}

export function sideFetchBody(method, params) {
  const source = params || {};
  if (!UUID.test(source.installationId || "") || !UUID.test(source.requestId || "") || source.generation !== 1) {
    return null;
  }
  if (method === GET_WATCH_PROVISION_V1) {
    const body = {
      operation: "pending",
      installationId: source.installationId,
      requestId: source.requestId,
      generation: 1,
    };
    const witness = sanitizeWitness(source.witness);
    if (witness) body.witness = witness;
    return body;
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

// @zeppos/zml 0.0.38 BaseSideService.fetch is global fetch. It copies
// timeout onto the init object (default 10000) and does not abort. The
// messaging request() path does abort with its own timer. This deadline is
// the one the side service enforces around that fetch.
export const PROVISION_DEADLINE_MS = 4000;
export const PROVISION_PAGE_TIMEOUT_MS = 8000;

export function fetchWithDeadline(start, ms, clock) {
  const schedule = clock && clock.schedule ? clock.schedule : setTimeout;
  const cancel = clock && clock.cancel ? clock.cancel : clearTimeout;
  return new Promise((resolve, reject) => {
    let settled = false;
    const timer = schedule(() => {
      if (settled) return;
      settled = true;
      const error = new Error("deadline");
      error.reason = "deadline";
      reject(error);
    }, ms);
    Promise.resolve()
      .then(start)
      .then((value) => {
        if (settled) return;
        settled = true;
        cancel(timer);
        resolve(value);
      }, (err) => {
        if (settled) return;
        settled = true;
        cancel(timer);
        reject(err);
      });
  });
}

function parseJson(text) {
  try {
    return JSON.parse(text);
  } catch (err) {
    return null;
  }
}

function transportFailure(reason, status) {
  return { ok: false, disposition: "unavailable", reason: reason, durable: false, httpStatus: status == null ? null : status, body: null };
}

export function normalizeTransportResponse(raw) {
  if (raw == null || typeof raw === "number" || typeof raw === "boolean") return transportFailure("malformed", null);
  let status = null;
  let body = raw;
  if (typeof raw === "string") {
    body = parseJson(raw);
    if (body == null) return transportFailure("malformed", null);
  } else if (typeof raw === "object") {
    if (typeof raw.status === "number") status = raw.status;
    else if (typeof raw.statusCode === "number") status = raw.statusCode;
    if (status != null && raw.disposition == null) {
      if (typeof raw.body === "string") {
        body = parseJson(raw.body);
        if (body == null) return transportFailure("malformed", status);
      } else if (raw.body && typeof raw.body === "object" && !Array.isArray(raw.body)) {
        body = raw.body;
      } else {
        return transportFailure("malformed", status);
      }
    }
  } else {
    return transportFailure("malformed", null);
  }
  if (status != null && status !== 200) return transportFailure("http-" + status, status);
  if (!body || typeof body !== "object" || Array.isArray(body)) return transportFailure("malformed", status);
  const disposition = body.disposition;
  if (disposition !== "prepared" && disposition !== "locked" && disposition !== "recorded" && disposition !== "refused" && disposition !== "unavailable") {
    return transportFailure("disposition", status);
  }
  if (status === 200 && (disposition === "refused" || disposition === "unavailable")) {
    return transportFailure("contradictory", status);
  }
  if (disposition === "prepared" && (body.durable === true || typeof body.canonical !== "string" || body.saved === true || body.d1Certified === true)) {
    return transportFailure("contradictory", status);
  }
  if (disposition === "locked" && (body.durable !== true || body.saved === true || body.d1Certified === true)) {
    return transportFailure("contradictory", status);
  }
  if (disposition === "recorded" && (body.saved === true || body.d1Certified === true || body.durable === true)) {
    return transportFailure("contradictory", status);
  }
  if (disposition === "prepared" || disposition === "locked" || disposition === "recorded") {
    return { ok: true, disposition: disposition, reason: body.reason || "", durable: body.durable === true, httpStatus: status, body: body };
  }
  return { ok: false, disposition: disposition, reason: body.reason || disposition, durable: false, httpStatus: status, body: null };
}

export function answerFromTransport(raw) {
  const normalized = normalizeTransportResponse(raw);
  if (normalized.ok) return normalized.body;
  return { disposition: normalized.disposition === "refused" ? "refused" : "unavailable", reason: normalized.reason, durable: false };
}

export function readTransportPayload(response) {
  if (response && typeof response.status === "number" && typeof response.text === "function") {
    return Promise.resolve(response.text()).then((text) => normalizeTransportResponse({ status: response.status, body: text }));
  }
  return Promise.resolve(normalizeTransportResponse(response));
}

function provisionLog(log, fields) {
  const write = log || function (line) { console.log(line); };
  const parts = ["FORREF_PROVISION"];
  const keys = Object.keys(fields);
  for (let i = 0; i < keys.length; i += 1) {
    const value = fields[keys[i]];
    if (value == null || value === "") continue;
    parts.push(keys[i] + "=" + value);
  }
  write(parts.join(" "));
}

export function acceptPrepared(body, installationId, requestId) {
  if (!body || typeof body !== "object") return { ok: false, reason: "unavailable" };
  if (body.disposition !== "prepared") {
    const detail = body.reason && body.reason !== body.disposition ? body.reason : body.disposition;
    return { ok: false, reason: detail || "unavailable" };
  }
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

const handshakeOpen = new Set();

function forwardPhase(current, next) {
  const rank = { pending: 0, verified: 1, activated: 2, reported: 3 };
  if ((rank[current] || 0) > (rank[next] || 0)) return current;
  return next;
}

async function ask(deps, method, params) {
  provisionLog(deps.log, {
    tx: "request",
    hop: "device",
    method: method,
    installation: params.installationId,
    request: params.requestId,
    match: params.matchId || "",
    hash: params.contentHash || "",
    generation: params.generation,
  });
  let raw;
  try {
    raw = await deps.request({ method: method, params: params });
  } catch (err) {
    const category = classifyFetchFailure(err);
    provisionLog(deps.log, {
      tx: "response",
      hop: "device",
      category: category,
      method: method,
      reason: category,
      request: params.requestId,
    });
    return { disposition: "unavailable", reason: category, hop: "device", category: category, durable: false };
  }
  const normalized = normalizeTransportResponse(raw);
  const source = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {};
  const hop = typeof source.hop === "string" && source.hop ? source.hop : "watch";
  const category = typeof source.category === "string" && source.category ? source.category : normalized.reason || "";
  provisionLog(deps.log, {
    tx: "response",
    hop: normalized.ok ? "bridge" : hop,
    category: normalized.ok ? "ok" : category,
    method: method,
    http: normalized.httpStatus == null ? "" : normalized.httpStatus,
    disposition: normalized.disposition,
    reason: normalized.reason || "",
    request: params.requestId,
  });
  if (!normalized.ok) {
    return {
      disposition: normalized.disposition === "refused" ? "refused" : "unavailable",
      reason: normalized.reason || source.reason || "unavailable",
      hop: hop,
      category: category,
      durable: false,
    };
  }
  return normalized.body;
}

function openHandshake(deps) {
  const installation = deps.loadInstallation();
  if (!installation.ok) {
    return { ok: false, installation: null, result: { ok: false, stage: "identity", reason: installation.reason || "installation", transport: "" } };
  }
  const key = installation.id;
  if (handshakeOpen.has(key)) {
    return { ok: false, installation: null, result: { ok: false, stage: "identity", reason: "busy", installationId: installation.id, transport: "" } };
  }
  handshakeOpen.add(key);
  return { ok: true, installation: installation, result: null };
}

export function pairingRetryable(view) {
  if (!view || view.ok) return false;
  if (view.stage !== "transport") return false;
  const category = view.category || "";
  return category === "timeout" || category === "connection-refused" || category === "transport";
}

export function pairingPresentation(view, attempt, limit) {
  if (view && view.ok) {
    return { done: true, view: Object.assign({}, view, { result: "verified", attempts: attempt }) };
  }
  if (pairingRetryable(view) && attempt < limit) return { done: false, view: view };
  const reason = view && view.reason ? String(view.reason) : "";
  let result = "failed";
  if (pairingRetryable(view)) result = "phone-unreachable";
  else if (reason.indexOf("installation") >= 0 || reason.indexOf("recovery-required") >= 0 || reason.indexOf("correlation-conflict") >= 0) {
    result = "writer-kept";
  }
  return { done: true, view: Object.assign({}, view || {}, { result: result, attempts: attempt }) };
}

export async function confirmPairing(deps) {
  const limit = deps && deps.attempts ? deps.attempts : 3;
  let last = { ok: false, stage: "transport", reason: "transport", category: "transport", hop: "fetch" };
  for (let attempt = 1; attempt <= limit; attempt += 1) {
    last = await runPrepare(deps);
    const presented = pairingPresentation(last, attempt, limit);
    if (presented.done) return presented.view;
    if (deps && typeof deps.wait === "function") await deps.wait(attempt);
  }
  return pairingPresentation(last, limit, limit).view;
}

export async function runPrepare(deps) {
  const opened = openHandshake(deps);
  if (!opened.ok) return opened.result;
  try {
    return await runPrepareBody(deps, opened.installation);
  } finally {
    handshakeOpen.delete(opened.installation.id);
  }
}

export async function runHandshake(deps) {
  const opened = openHandshake(deps);
  if (!opened.ok) return opened.result;
  try {
    return await runHandshakeBody(deps, opened.installation);
  } finally {
    handshakeOpen.delete(opened.installation.id);
  }
}

async function runPrepareBody(deps, installation) {
  let correlation = loadCorrelation(deps.requestStore, installation.id, deps.allocate);
  if (!correlation.ok) {
    return { ok: false, stage: "identity", reason: correlation.reason, installationId: installation.id, requestId: correlation.requestId || "", transport: "" };
  }
  const witness = typeof deps.readWitness === "function" ? deps.readWitness() : null;
  const pending = await ask(deps, GET_WATCH_PROVISION_V1, {
    installationId: installation.id,
    requestId: correlation.requestId,
    generation: 1,
    witness: witness,
  });
  if (correlation.matchId && pending && pending.disposition === "prepared" && (pending.matchId !== correlation.matchId || pending.contentHash !== correlation.contentHash)) {
    provisionLog(deps.log, { tx: "recover", reason: "binding", request: correlation.requestId, match: correlation.matchId });
    return {
      ok: false,
      stage: "verified",
      reason: "binding",
      installationId: installation.id,
      requestId: correlation.requestId,
      matchId: correlation.matchId,
      contentHash: correlation.contentHash,
      transport: "refused",
    };
  }
  const verified = applyPrepared(deps.admission, pending, installation.id, correlation.requestId);
  if (!verified.ok) {
    const local = !!(pending && pending.disposition === "prepared");
    const hop = local ? "watch" : (pending && pending.hop) || "watch";
    const detail = verified.reason || "unavailable";
    const category = local ? detail : (pending && pending.category) || detail;
    provisionLog(deps.log, {
      tx: "normalize",
      hop: hop,
      category: category,
      reason: detail,
      request: correlation.requestId,
      match: (pending && pending.matchId) || correlation.matchId || "",
      hash: (pending && pending.contentHash) || correlation.contentHash || "",
    });
    return {
      ok: false,
      stage: local ? "prepared" : "transport",
      reason: local ? detail : hop + ":" + detail,
      hop: hop,
      category: category,
      installationId: installation.id,
      requestId: correlation.requestId,
      transport: pending && pending.disposition || "unavailable",
      durable: false,
    };
  }
  correlation = saveCorrelation(deps.requestStore, {
    installationId: installation.id,
    requestId: correlation.requestId,
    generation: 1,
    phase: forwardPhase(correlation.phase, "verified"),
    matchId: verified.matchId,
    contentHash: verified.contentHash,
  });
  if (!correlation.ok) {
    return { ok: false, stage: "verified", reason: "correlation-write", installationId: installation.id, requestId: correlation.requestId, matchId: verified.matchId, contentHash: verified.contentHash, transport: "" };
  }
  provisionLog(deps.log, { tx: "transition", phase: correlation.phase, request: correlation.requestId, match: verified.matchId, hash: verified.contentHash, canonical: "accepted" });
  return {
    ok: true,
    stage: "prepared",
    reason: "",
    installationId: installation.id,
    requestId: correlation.requestId,
    matchId: verified.matchId,
    contentHash: verified.contentHash,
    homeName: verified.homeName,
    awayName: verified.awayName,
    transport: "prepared",
    durable: false,
    receipt: verified.receipt,
  };
}

async function runHandshakeBody(deps, installation) {
  const prepared = await runPrepareBody(deps, installation);
  if (!prepared.ok) return prepared;
  const verified = {
    matchId: prepared.matchId,
    contentHash: prepared.contentHash,
    homeName: prepared.homeName,
    awayName: prepared.awayName,
    receipt: prepared.receipt,
  };
  let correlation = {
    requestId: prepared.requestId,
    phase: "verified",
    matchId: prepared.matchId,
    contentHash: prepared.contentHash,
  };
  const locked = await ask(deps, SUBMIT_WATCH_LOCK_V1, verified.receipt);
  const activation = applyActivation(deps.admission, locked, verified.receipt);
  if (!activation.ok) {
    provisionLog(deps.log, { tx: "recover", reason: activation.reason || "lock", request: correlation.requestId, match: verified.matchId });
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
  const activated = saveCorrelation(deps.requestStore, {
    installationId: installation.id,
    requestId: correlation.requestId,
    generation: 1,
    phase: forwardPhase(correlation.phase, "activated"),
    matchId: verified.matchId,
    contentHash: verified.contentHash,
  });
  if (!activated.ok) {
    return { ok: false, stage: "lock", reason: "correlation-write", installationId: installation.id, requestId: correlation.requestId, matchId: verified.matchId, contentHash: verified.contentHash, transport: "locked", durable: true };
  }
  provisionLog(deps.log, { tx: "transition", phase: activated.phase, request: correlation.requestId, match: verified.matchId, hash: verified.contentHash });
  const reported = await ask(deps, REPORT_WATCH_ACTIVATED_V1, activation.report);
  const recorded = reported && reported.disposition === "recorded";
  if (recorded) {
    const reportedCorrelation = saveCorrelation(deps.requestStore, {
      installationId: installation.id,
      requestId: correlation.requestId,
      generation: 1,
      phase: "reported",
      matchId: verified.matchId,
      contentHash: verified.contentHash,
    });
    if (!reportedCorrelation.ok) {
      return { ok: false, stage: "report", reason: "correlation-write", installationId: installation.id, requestId: correlation.requestId, matchId: verified.matchId, contentHash: verified.contentHash, homeName: verified.homeName, awayName: verified.awayName, transport: "recorded", durable: true };
    }
    provisionLog(deps.log, { tx: "transition", phase: "reported", request: correlation.requestId, match: verified.matchId, hash: verified.contentHash });
  } else {
    provisionLog(deps.log, { tx: "recover", reason: "report-lost", request: correlation.requestId, match: verified.matchId, phase: "activated" });
  }
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

// Side service request. The device page calls messaging.request. This posts
// that message to the phone debug bridge and returns the reply body.
export function classifyFetchFailure(err) {
  const reason = err && typeof err === "object" && err.reason ? String(err.reason) : "";
  const message = err && typeof err === "object" && err.message ? String(err.message) : String(err || "");
  const text = (reason + " " + message).toLowerCase();
  if (reason === "deadline" || text.includes("timeout") || text.includes("timed out") || text.includes("aborterror")) {
    return "timeout";
  }
  if (text.includes("permission") || text.includes("eacces") || text.includes("denied")) {
    return "permission";
  }
  if (text.includes("econnrefused") || text.includes("connection refused")) {
    return "connection-refused";
  }
  return "transport";
}

export function phoneReasonCode(response) {
  if (!response || typeof response !== "object" || typeof response.status !== "number") return "";
  let body = response.body;
  if (typeof body === "string") body = parseJson(body);
  if (!body || typeof body !== "object" || Array.isArray(body)) return "";
  if (typeof body.reason !== "string" || body.reason.length > 80) return "";
  return body.reason;
}

export function classifySideFailure(err, normalized) {
  if (err) {
    const category = classifyFetchFailure(err);
    return { hop: "fetch", category: category, reason: category, disposition: "unavailable" };
  }
  const status = normalized && typeof normalized.httpStatus === "number" ? normalized.httpStatus : null;
  const reason = normalized && normalized.reason ? String(normalized.reason) : "unavailable";
  if (reason === "malformed" || reason === "contradictory" || reason === "disposition") {
    return { hop: "normalize", category: "malformed", reason: reason, disposition: "unavailable" };
  }
  if (status === 401 || status === 403 || reason === "http-401" || reason === "http-403") {
    return { hop: "bridge", category: "permission", reason: reason, disposition: "unavailable" };
  }
  if ((status != null && status >= 400) || reason.indexOf("http-") === 0) {
    return {
      hop: "bridge",
      category: "http-refusal",
      reason: reason,
      disposition: normalized && normalized.disposition === "refused" ? "refused" : "unavailable",
    };
  }
  if (normalized && normalized.disposition === "refused") {
    return { hop: "bridge", category: "http-refusal", reason: reason, disposition: "refused" };
  }
  return { hop: "fetch", category: "transport", reason: reason, disposition: "unavailable" };
}

function sideFailure(classified, detail) {
  return {
    disposition: classified.disposition,
    reason: detail || classified.reason,
    hop: classified.hop,
    category: classified.category,
    durable: false,
  };
}

export function dispatchSideRequest(req, fetchImpl, url) {
  const endpoint = url || PROVISION_BRIDGE_URL;
  const method = req && req.method ? req.method : "";
  const params = (req && req.params) || {};
  const requestId = params.requestId || "";
  if (!isProvisionMethod(method)) {
    provisionLog(null, { tx: "side", hop: "side", method: method, request: requestId, disposition: "refused", reason: "method" });
    return Promise.resolve({ disposition: "refused", reason: "method", hop: "side", category: "transport", durable: false });
  }
  const body = sideFetchBody(method, params);
  if (!body) {
    provisionLog(null, { tx: "side", hop: "side", method: method, request: requestId, disposition: "refused", reason: "message" });
    return Promise.resolve({ disposition: "refused", reason: "message", hop: "side", category: "malformed", durable: false });
  }
  const started = Date.now();
  provisionLog(null, {
    tx: "side",
    hop: "side",
    method: method,
    installation: body.installationId,
    request: body.requestId,
    match: body.matchId || "",
    hash: body.contentHash || "",
  });
  return fetchWithDeadline(() => fetchImpl({
    url: endpoint,
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  }), PROVISION_DEADLINE_MS).then((response) => {
    const elapsed = Date.now() - started;
    const phoneReason = phoneReasonCode(response);
    return readTransportPayload(response).then((normalized) => {
      if (normalized && normalized.ok) {
        provisionLog(null, {
          tx: "fetch",
          hop: "bridge",
          category: "ok",
          method: method,
          request: body.requestId,
          elapsed: elapsed,
          http: normalized.httpStatus == null ? "" : normalized.httpStatus,
          disposition: normalized.disposition,
        });
        return normalized.body;
      }
      const classified = classifySideFailure(null, normalized);
      const detail = phoneReason && classified.category === "http-refusal" ? phoneReason : classified.reason;
      provisionLog(null, {
        tx: "fetch",
        hop: classified.hop,
        category: classified.category,
        method: method,
        request: body.requestId,
        elapsed: elapsed,
        http: normalized && normalized.httpStatus != null ? normalized.httpStatus : "",
        disposition: classified.disposition,
        reason: detail,
      });
      return sideFailure(classified, detail);
    });
  }).catch((err) => {
    const elapsed = Date.now() - started;
    const classified = classifySideFailure(err, null);
    provisionLog(null, {
      tx: "fetch",
      hop: classified.hop,
      category: classified.category,
      method: method,
      request: body.requestId,
      elapsed: elapsed,
      reason: classified.reason,
    });
    return sideFailure(classified, classified.reason);
  });
}

function identityField(value) {
  return value == null ? "" : String(value);
}

export function sideBuildRecord() {
  return {
    disposition: "side-build",
    build: BUILD_NAME,
    rev: BUILD_REV,
    version: BUILD_VERSION,
    code: BUILD_CODE,
  };
}

export function sameBuild(record) {
  if (!record || record.disposition !== "side-build") return false;
  return identityField(record.build) === BUILD_NAME &&
    identityField(record.rev) === BUILD_REV &&
    identityField(record.version) === BUILD_VERSION &&
    identityField(record.code) === String(BUILD_CODE);
}

export function describeFetchException(err) {
  const name = err && typeof err === "object" && err.name ? String(err.name) : "";
  const message = err && typeof err === "object" && err.message
    ? String(err.message)
    : (err == null ? "" : String(err));
  const code = err && typeof err === "object" && (err.code || err.errno)
    ? String(err.code || err.errno)
    : "";
  const reason = err && typeof err === "object" && err.reason ? String(err.reason) : "";
  return {
    name: name.slice(0, 40),
    message: message.replace(/\s+/g, " ").slice(0, 180),
    code: code.slice(0, 40),
    reason: reason.slice(0, 40),
  };
}

// Read-only connectivity check. The body is not a provision operation, so the
// phone debug bridge refuses it before it reads or writes a match.
export function probeBridge(fetchImpl, url) {
  const endpoint = url || PROVISION_BRIDGE_URL;
  const started = Date.now();
  provisionLog(null, { tx: "probe", hop: "fetch", method: "POST" });
  return fetchWithDeadline(() => fetchImpl({
    url: endpoint,
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: PROBE_BODY,
  }), PROVISION_DEADLINE_MS).then((response) => {
    const elapsed = Date.now() - started;
    const status = response && typeof response.status === "number" ? response.status : "";
    return readTransportPayload(response).then((normalized) => {
      const reason = phoneReasonCode(response) || (normalized && normalized.reason) || "";
      const answered = typeof status === "number" && status > 0;
      provisionLog(null, {
        tx: "probe",
        hop: answered ? "bridge" : "fetch",
        category: answered ? "answered" : "transport",
        http: status,
        reason: reason,
        elapsed: elapsed,
      });
      return {
        disposition: "probe",
        hop: answered ? "bridge" : "fetch",
        category: answered ? "answered" : "transport",
        http: status,
        reason: reason || (answered ? "http" : "transport"),
        detail: "",
        durable: false,
      };
    });
  }).catch((err) => {
    const elapsed = Date.now() - started;
    const described = describeFetchException(err);
    const category = classifyFetchFailure(err);
    provisionLog(null, {
      tx: "probe",
      hop: "fetch",
      category: category,
      elapsed: elapsed,
      name: described.name,
      error: described.message,
      code: described.code,
      reason: described.reason || category,
    });
    return {
      disposition: "probe",
      hop: "fetch",
      category: category,
      reason: category,
      detail: [described.name, described.code, described.message].filter(Boolean).join(" "),
      http: "",
      durable: false,
    };
  });
}

export async function runSideDiagnostic(deps) {
  provisionLog(deps && deps.log, {
    tx: "device-build",
    build: BUILD_NAME,
    rev: BUILD_REV,
    version: BUILD_VERSION,
    code: BUILD_CODE,
  });
  let raw;
  try {
    raw = await deps.request({ method: GET_SIDE_BUILD_V1, params: {} });
  } catch (err) {
    const described = describeFetchException(err);
    provisionLog(deps && deps.log, {
      tx: "parity",
      match: 0,
      reason: "request",
      error: described.message,
    });
    return {
      ok: false,
      stage: "parity",
      reason: "parity:request",
      detail: described.message,
      hop: "device",
      category: "request",
      durable: false,
      transport: "parity",
    };
  }
  const side = raw && typeof raw === "object" ? raw : {};
  const match = sameBuild(side) ? 1 : 0;
  provisionLog(deps && deps.log, {
    tx: "parity",
    match: match,
    build: BUILD_NAME,
    rev: BUILD_REV,
    sideBuild: side.build || "",
    sideRev: side.rev || "",
    sideVersion: side.version || "",
    sideCode: side.code == null ? "" : side.code,
    reason: match ? "match" : (side.reason || side.disposition || "absent"),
  });
  if (!match) {
    return {
      ok: false,
      stage: "parity",
      reason: "parity:" + (side.reason || side.disposition || "absent"),
      hop: "side",
      category: "parity",
      sideBuild: side.build || "",
      sideRev: side.rev || "",
      detail: "",
      durable: false,
      transport: "parity",
    };
  }
  let probe;
  try {
    probe = await deps.request({
      method: PROBE_BRIDGE_V1,
      params: sideBuildRecord(),
    });
  } catch (err) {
    const described = describeFetchException(err);
    provisionLog(deps && deps.log, {
      tx: "probe-result",
      hop: "device",
      category: "request",
      reason: "request",
      detail: described.message,
    });
    return {
      ok: false,
      stage: "probe",
      reason: "probe:request",
      detail: described.message,
      hop: "device",
      category: "request",
      durable: false,
      transport: "probe",
    };
  }
  const body = probe && typeof probe === "object" ? probe : {};
  provisionLog(deps && deps.log, {
    tx: "probe-result",
    hop: body.hop || "",
    category: body.category || "",
    http: body.http == null ? "" : body.http,
    reason: body.reason || "",
    detail: body.detail || "",
  });
  return {
    ok: body.category === "answered",
    stage: "probe",
    reason: "probe:" + (body.reason || body.category || "absent"),
    hop: body.hop || "",
    category: body.category || "",
    detail: body.detail || "",
    http: body.http,
    durable: false,
    transport: "probe",
  };
}
