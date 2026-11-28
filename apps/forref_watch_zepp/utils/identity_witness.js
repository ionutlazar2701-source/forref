import { sha256Hex, sha256Of, utf8Bytes } from "./sha256_hex.js";
import { BUILD_CODE, BUILD_NAME, BUILD_VERSION } from "./build_stamp.js";

export const WITNESS_SCHEMA = "forref.identity-witness.v1";
export const DIGEST_DOMAIN = "forref-candidate-v1:";
export const DIGEST_DOMAIN_V2 = "forref-candidate-v2:";
export const EVIDENCE_GRADE = "watch-message-observed/unverified-device-identity";

const HEX64 = /^[0-9a-fA-F]{64}$/;

function isHexCode(code) {
  return (code >= 0x30 && code <= 0x39) ||
    (code >= 0x61 && code <= 0x66) ||
    (code >= 0x41 && code <= 0x46);
}

function profileOf(value) {
  let hex = 1;
  let ascii = 1;
  let ctrl = 0;
  for (let i = 0; i < value.length; i += 1) {
    const code = value.charCodeAt(i);
    if (!isHexCode(code)) hex = 0;
    if (code < 0x20 || code > 0x7e) ascii = 0;
    if (code < 0x20 || code === 0x7f) ctrl += 1;
  }
  return {
    length: value.length,
    utf8: utf8Bytes(value).length,
    hex,
    ascii,
    ctrl,
  };
}

const EMPTY_PROFILE = { length: 0, utf8: 0, hex: 0, ascii: 0, ctrl: 0 };

export function classifyPlatformId(value) {
  if (value == null) {
    return { ok: false, className: "unavailable", digestVersion: 0, ...EMPTY_PROFILE };
  }
  if (typeof value !== "string") {
    return { ok: false, className: "non-string", digestVersion: 0, ...EMPTY_PROFILE };
  }
  const profile = profileOf(value);
  if (value.length === 0) {
    return { ok: false, className: "empty", digestVersion: 0, ...profile };
  }
  if (HEX64.test(value)) {
    return {
      ok: true,
      className: "hex64",
      digestVersion: 1,
      normalized: value.toLowerCase(),
      bytes: null,
      ...profile,
    };
  }
  if (value.length === 32) {
    const bytes = [];
    let hex = true;
    for (let i = 0; i < 32; i += 1) {
      const code = value.charCodeAt(i);
      if (code > 255) {
        return { ok: false, className: "non-byte32", digestVersion: 0, bytes: null, ...profile };
      }
      bytes.push(code);
      if (!isHexCode(code)) hex = false;
    }
    if (hex) {
      for (let i = 0; i < 32; i += 1) {
        if (bytes[i] >= 0x41 && bytes[i] <= 0x46) bytes[i] += 0x20;
      }
    }
    return {
      ok: true,
      className: hex ? "hex32" : "bytes32",
      digestVersion: 2,
      normalized: hex ? String.fromCharCode.apply(null, bytes) : null,
      bytes,
      ...profile,
    };
  }
  return { ok: false, className: "unsupported-or-invalid", digestVersion: 0, bytes: null, ...profile };
}

export function candidateDigestHex(normalizedHex) {
  const classified = classifyPlatformId(normalizedHex);
  if (!classified.ok || classified.digestVersion !== 1 || classified.normalized !== normalizedHex) return "";
  return sha256Hex(DIGEST_DOMAIN + normalizedHex);
}

export function candidateDigestV2Hex(bytes) {
  if (!bytes || bytes.length !== 32) return "";
  for (let i = 0; i < 32; i += 1) {
    if ((bytes[i] & 0xff) !== bytes[i]) return "";
  }
  return sha256Of(utf8Bytes(DIGEST_DOMAIN_V2).concat(bytes));
}

export function digestPreview(hex) {
  if (typeof hex !== "string" || hex.length !== 64) return "";
  return hex.slice(0, 4) + "..." + hex.slice(60);
}

function witnessLine(classified, preview) {
  const base = "FORREF_WITNESS kind=" + (classified.ok ? "platform_uuid" : "absent") +
    " class=" + classified.className +
    " len=" + classified.length +
    " utf8=" + classified.utf8 +
    " hex=" + classified.hex +
    " ascii=" + classified.ascii +
    " ctrl=" + classified.ctrl;
  const tail = classified.ok ? " preview=" + preview + " v=" + classified.digestVersion : "";
  return base + tail + " grade=" + EVIDENCE_GRADE;
}

export function witnessFromInfo(info) {
  const source = info && typeof info === "object" ? info : {};
  const classified = classifyPlatformId(source.uuid);
  const builds = "device=" + BUILD_NAME + "/" + BUILD_VERSION + "/" + BUILD_CODE;
  if (!classified.ok) {
    return { ok: false, line: witnessLine(classified, ""), witness: null };
  }
  const digest = classified.digestVersion === 1
    ? candidateDigestHex(classified.normalized)
    : candidateDigestV2Hex(classified.bytes);
  const preview = digestPreview(digest);
  return {
    ok: true,
    line: witnessLine(classified, preview),
    witness: {
      schema: WITNESS_SCHEMA,
      candidateKind: "platform_uuid",
      candidateDigest: digest,
      digestVersion: classified.digestVersion,
      evidenceGrade: EVIDENCE_GRADE,
      sourceBuilds: builds,
    },
  };
}

export function sanitizeWitness(witness) {
  if (!witness || typeof witness !== "object" || Array.isArray(witness)) return null;
  if (Object.prototype.hasOwnProperty.call(witness, "uuid")) return null;
  if (Object.prototype.hasOwnProperty.call(witness, "platformUuid")) return null;
  if (witness.schema !== WITNESS_SCHEMA) return null;
  if (witness.digestVersion !== 1 && witness.digestVersion !== 2) return null;
  if (witness.evidenceGrade !== EVIDENCE_GRADE) return null;
  if (witness.candidateKind !== "platform_uuid") return null;
  if (typeof witness.candidateDigest !== "string" || !/^[0-9a-f]{64}$/.test(witness.candidateDigest)) return null;
  const builds = typeof witness.sourceBuilds === "string" ? witness.sourceBuilds.slice(0, 160) : "";
  return {
    schema: WITNESS_SCHEMA,
    candidateKind: "platform_uuid",
    candidateDigest: witness.candidateDigest,
    digestVersion: witness.digestVersion,
    evidenceGrade: EVIDENCE_GRADE,
    sourceBuilds: builds,
  };
}
