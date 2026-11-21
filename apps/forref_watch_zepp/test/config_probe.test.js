import test from "node:test";
import assert from "node:assert/strict";
import {
  CONFIGURATION_STORED,
  GET_CONFIGURATION,
  STATIC_CONFIGURATION,
  acceptPayload,
  contentHash,
  receiptRequest,
  sideAnswer,
  storeRecord,
} from "../utils/config_probe.js";

function memoryIo() {
  let text = "";
  return {
    write(value) {
      text = value;
    },
    read() {
      return text;
    },
    snapshot() {
      return text;
    },
  };
}

test("the side service returns the static configuration and its hash", () => {
  const answer = sideAnswer({ method: GET_CONFIGURATION, params: {} });
  assert.equal(answer.error, null);
  assert.equal(answer.data.disposition, "payload");
  assert.equal(answer.data.payload.matchId, "probe-a-static");
  assert.equal(answer.data.payload.source, "side-service-static");
  assert.equal(answer.data.contentHash, contentHash(STATIC_CONFIGURATION));
  assert.equal(Object.hasOwn(answer.data.payload, "score"), false);
  assert.equal(Object.hasOwn(answer.data.payload, "events"), false);
});

test("the watch stores the payload only after the hash matches and then receives a receipt", () => {
  const answer = sideAnswer({ method: GET_CONFIGURATION, params: {} });
  const accepted = acceptPayload(answer.data);
  assert.equal(accepted.ok, true);
  const io = memoryIo();
  const stored = storeRecord(io, accepted.record);
  assert.equal(stored.stored, true);
  assert.equal(io.snapshot().includes("probe-a-static"), true);
  const receipt = sideAnswer(receiptRequest(accepted.record));
  assert.equal(receipt.error, null);
  assert.equal(receipt.data.disposition, "recorded");
  assert.equal(receipt.data.contentHash, accepted.record.contentHash);
});

test("a hash mismatch, an unknown version, and a bad receipt are refused", () => {
  const answer = sideAnswer({ method: GET_CONFIGURATION, params: {} });
  const tampered = {
    disposition: "payload",
    payload: Object.assign({}, answer.data.payload, { payloadVersion: 2 }),
    contentHash: answer.data.contentHash,
  };
  assert.equal(acceptPayload(tampered).reason, "version");
  const broken = Object.assign({}, answer.data, { contentHash: "00000000" });
  assert.equal(acceptPayload(broken).reason, "hash");
  const receipt = sideAnswer({
    method: CONFIGURATION_STORED,
    params: {
      payloadVersion: 1,
      matchId: "probe-a-static",
      contentHash: "00000000",
    },
  });
  assert.equal(receipt.error, "reject");
  assert.equal(sideAnswer({ method: "OTHER" }).error, "unknown-method");
});

test("a readback that does not match the written text is not stored", () => {
  const answer = sideAnswer({ method: GET_CONFIGURATION, params: {} });
  const accepted = acceptPayload(answer.data);
  const stored = storeRecord(
    {
      write() {},
      read() {
        return "torn";
      },
    },
    accepted.record
  );
  assert.equal(stored.stored, false);
  assert.equal(stored.reason, "readback");
});
