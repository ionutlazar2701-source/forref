import { sha256Hex } from "./sha256_hex.js";
import { BUILD_CODE, BUILD_NAME, BUILD_VERSION } from "./build_stamp.js";

export const WITNESS_SCHEMA = "forref.identity-witness.v1";
export const DIGEST_DOMAIN = "forref-candidate-v1:";
export const EVIDENCE_GRADE = "watch-message-observed/unverified-device-identity";

const HEX64 = /^[0-9a-fA-F]{64}$/;

export function classifyPlatformId(value) {
  if (value == null) return { ok: false, className: "unavailable", length: 0 };
  if (typeof value !== "string") return { ok: false, className: "non-string", length: 0 };
  if (value.length === 0) return { ok: false, className: "empty", length: 0 };
  if (!HEX64.test(value)) {
    return { ok: false, className: "unsupported-or-invalid", length: value.length };
  }
  return { ok: true, className: "hex64", length: 64, normalized: value.toLowerCase() };
}

export function candidateDigestHex(normalizedHex) {
  const classified = classifyPlatformId(normalizedHex);
  if (!classified.ok || classified.normalized !== normalizedHex) return "";
  return sha256Hex(DIGEST_DOMAIN + normalizedHex);
}

export function digestPreview(hex) {
  if (typeof hex !== "string" || hex.length !== 64) return "";
  return hex.slice(0, 4) + "..." + hex.slice(60);
}

export function witnessFromInfo(info) {
  const source = info && typeof info === "object" ? info : {};
  const classified = classifyPlatformId(source.uuid);
  const builds = "device=" + BUILD_NAME + "/" + BUILD_VERSION + "/" + BUILD_CODE;
  if (!classified.ok) {
    return {
      ok: false,
      line: "FORREF_WITNESS kind=absent class=" + classified.className + " len=" + classified.length + " grade=" + EVIDENCE_GRADE,
      witness: null,
    };
  }
  const digest = candidateDigestHex(classified.normalized);
  const preview = digestPreview(digest);
  return {
    ok: true,
    line: "FORREF_WITNESS kind=platform_uuid class=hex64 len=64 preview=" + preview + " grade=" + EVIDENCE_GRADE,
    witness: {
      schema: WITNESS_SCHEMA,
      candidateKind: "platform_uuid",
      candidateDigest: digest,
      digestVersion: 1,
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
  if (witness.digestVersion !== 1) return null;
  if (witness.evidenceGrade !== EVIDENCE_GRADE) return null;
  if (witness.candidateKind !== "platform_uuid") return null;
  if (typeof witness.candidateDigest !== "string" || !/^[0-9a-f]{64}$/.test(witness.candidateDigest)) return null;
  const builds = typeof witness.sourceBuilds === "string" ? witness.sourceBuilds.slice(0, 160) : "";
  return {
    schema: WITNESS_SCHEMA,
    candidateKind: "platform_uuid",
    candidateDigest: witness.candidateDigest,
    digestVersion: 1,
    evidenceGrade: EVIDENCE_GRADE,
    sourceBuilds: builds,
  };
}
