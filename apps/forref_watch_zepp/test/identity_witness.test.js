import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";
import { sha256Hex } from "../utils/sha256_hex.js";
import {
  DIGEST_DOMAIN,
  DIGEST_DOMAIN_V2,
  EVIDENCE_GRADE,
  candidateDigestHex,
  candidateDigestV2Hex,
  classifyPlatformId,
  digestPreview,
  sanitizeWitness,
  witnessFromInfo,
} from "../utils/identity_witness.js";
import { sha256Of, utf8Bytes } from "../utils/sha256_hex.js";

const PLATFORM = "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff";
const HEX32 = "00112233445566778899aabbccddeeff";
const HEX32_DIGEST = "3be95c18a1a81de5a4165d603696e4fe42725cf7c1bc54b5807e1a6ad46358a0";
const OPAQUE = String.fromCharCode(...Array.from({ length: 31 }, () => 0x11), 0x80);
const OPAQUE_DIGEST = "cc618c08acccf2e1aeebcaa197faf07a188a72bf7de0088dfeb535372581f17a";

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
  assert.equal(read.witness.digestVersion, 1);
  const page = readFileSync(new URL("../page/gt/provision/index.page.js", import.meta.url), "utf8");
  assert.equal(page.includes("readWitness"), true);
  assert.equal(page.includes("platformUuid"), false);
});

test("a 32-byte platform id is digest version 2 and a version-1 digest stays put", () => {
  const upper = HEX32.toUpperCase();
  const classified = classifyPlatformId(upper);
  assert.equal(classified.ok, true);
  assert.equal(classified.className, "hex32");
  assert.equal(classified.digestVersion, 2);
  assert.equal(candidateDigestV2Hex(classified.bytes), HEX32_DIGEST);
  assert.equal(candidateDigestV2Hex(classified.bytes), sha256Of(utf8Bytes(DIGEST_DOMAIN_V2).concat(classified.bytes)));
  const read = witnessFromInfo({ uuid: upper });
  assert.equal(read.ok, true);
  assert.equal(read.witness.candidateDigest, HEX32_DIGEST);
  assert.equal(read.witness.digestVersion, 2);
  assert.equal(read.line.includes(upper), false);
  assert.equal(read.line.includes(HEX32), false);
  assert.equal(read.line.includes(HEX32_DIGEST), false);
  assert.equal(read.line.includes("class=hex32"), true);
  assert.equal(read.line.includes("len=32"), true);
  assert.equal(read.line.includes("v=2"), true);
  assert.equal(witnessFromInfo({ uuid: HEX32 }).witness.candidateDigest, read.witness.candidateDigest);
  const opaque = classifyPlatformId(OPAQUE);
  assert.equal(opaque.className, "bytes32");
  assert.equal(opaque.hex, 0);
  assert.equal(candidateDigestV2Hex(opaque.bytes), OPAQUE_DIGEST);
  const opaqueRead = witnessFromInfo({ uuid: OPAQUE });
  assert.equal(opaqueRead.line.includes(OPAQUE), false);
  assert.equal(opaqueRead.witness.candidateDigest, OPAQUE_DIGEST);
  assert.notEqual(HEX32_DIGEST, sha256Hex(DIGEST_DOMAIN + HEX32));
  assert.equal(candidateDigestHex(PLATFORM), "26c41755b96d53042c3b66daefff51082ea5ec9c70c4d4c6e0fffb6bde19954c");
  assert.equal(candidateDigestHex(HEX32), "");
});

test("missing, short, and non-hex values are not digests", () => {
  assert.equal(witnessFromInfo(null).ok, false);
  assert.equal(witnessFromInfo({}).line.includes("class=unavailable"), true);
  assert.equal(witnessFromInfo({ uuid: "abc" }).line.includes("class=unsupported-or-invalid"), true);
  assert.equal(witnessFromInfo({ uuid: "zzzz".repeat(16) }).witness, null);
  assert.equal(witnessFromInfo({ uuid: "g".repeat(32) }).ok, true);
  assert.equal(witnessFromInfo({ uuid: "g".repeat(31) }).ok, false);
  assert.equal(witnessFromInfo({ uuid: "g".repeat(33) }).ok, false);
  assert.equal(witnessFromInfo({ uuid: String.fromCharCode(0x100) + "a".repeat(31) }).line.includes("class=non-byte32"), true);
  assert.equal(witnessFromInfo({ uuid: 32 }).line.includes("class=non-string"), true);
  assert.equal(sanitizeWitness({ schema: "forref.identity-witness.v1", candidateKind: "platform_uuid", candidateDigest: HEX32_DIGEST, digestVersion: 2, evidenceGrade: EVIDENCE_GRADE }).digestVersion, 2);
  assert.equal(sanitizeWitness({ schema: "forref.identity-witness.v1", candidateKind: "platform_uuid", candidateDigest: HEX32_DIGEST, digestVersion: 3, evidenceGrade: EVIDENCE_GRADE }), null);
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
