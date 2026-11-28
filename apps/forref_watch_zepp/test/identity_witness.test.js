import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";
import { sha256Hex } from "../utils/sha256_hex.js";
import {
  DIGEST_DOMAIN,
  EVIDENCE_GRADE,
  candidateDigestHex,
  classifyPlatformId,
  digestPreview,
  sanitizeWitness,
  witnessFromInfo,
} from "../utils/identity_witness.js";

const PLATFORM = "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff";

test("sha256 of abc matches the published vector", () => {
  assert.equal(sha256Hex("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
});

test("a hex64 platform id becomes a domain-separated digest and the raw id stays out", () => {
  const upper = PLATFORM.toUpperCase();
  const classified = classifyPlatformId(upper);
  assert.equal(classified.ok, true);
  assert.equal(classified.normalized, PLATFORM);
  const digest = candidateDigestHex(classified.normalized);
  assert.equal(digest, sha256Hex(DIGEST_DOMAIN + PLATFORM));
  assert.equal(digest.length, 64);
  const read = witnessFromInfo({ uuid: upper, deviceSource: 9765120 });
  assert.equal(read.ok, true);
  assert.equal(read.witness.candidateDigest, digest);
  assert.equal(read.line.includes(PLATFORM), false);
  assert.equal(read.line.includes(upper), false);
  assert.equal(read.line.includes(digest), false);
  assert.equal(read.line.includes(digestPreview(digest)), true);
  assert.equal(read.line.includes("9765120"), false);
  assert.equal(read.witness.uuid, undefined);
  const page = readFileSync(new URL("../page/gt/provision/index.page.js", import.meta.url), "utf8");
  assert.equal(page.includes("readWitness"), true);
  assert.equal(page.includes("platformUuid"), false);
});

test("missing, short, and non-hex values are not digests", () => {
  assert.equal(witnessFromInfo(null).ok, false);
  assert.equal(witnessFromInfo({}).line.includes("class=unavailable"), true);
  assert.equal(witnessFromInfo({ uuid: "abc" }).line.includes("class=unsupported-or-invalid"), true);
  assert.equal(witnessFromInfo({ uuid: "zzzz".repeat(16) }).witness, null);
  assert.equal(candidateDigestHex("abc"), "");
  assert.equal(sanitizeWitness({ schema: "forref.identity-witness.v1", uuid: PLATFORM, candidateKind: "platform_uuid", candidateDigest: "ab".repeat(32), digestVersion: 1, evidenceGrade: EVIDENCE_GRADE }), null);
});

test("the side body keeps a valid witness and drops a raw platform id", async () => {
  const { sideFetchBody, GET_WATCH_PROVISION_V1 } = await import("../utils/provision_bridge.js");
  const digest = candidateDigestHex(PLATFORM);
  const body = sideFetchBody(GET_WATCH_PROVISION_V1, {
    installationId: "6f1e2d3c-4b5a-4678-9abc-def012345678",
    requestId: "11111111-2222-4333-8444-555555555555",
    generation: 1,
    witness: witnessFromInfo({ uuid: PLATFORM }).witness,
  });
  assert.equal(body.witness.candidateDigest, digest);
  assert.equal(JSON.stringify(body).includes(PLATFORM), false);
  const plain = sideFetchBody(GET_WATCH_PROVISION_V1, {
    installationId: "6f1e2d3c-4b5a-4678-9abc-def012345678",
    requestId: "11111111-2222-4333-8444-555555555555",
    generation: 1,
  });
  assert.equal(plain.witness, undefined);
  assert.equal(plain.operation, "pending");
});
