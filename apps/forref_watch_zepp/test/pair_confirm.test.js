import test from "node:test";
import assert from "node:assert/strict";
import { createMemoryTextStore } from "../utils/provision_transport.js";
import {
  confirmPairing,
  pairingPresentation,
  pairingRetryable,
} from "../utils/provision_bridge.js";

const installation = "22222222-2222-4222-8222-222222222222";

test("pairing retries a dead phone and keeps a stored writer", async () => {
  assert.equal(pairingRetryable({ ok: false, stage: "transport", category: "timeout" }), true);
  assert.equal(pairingRetryable({ ok: false, stage: "transport", category: "http-refusal" }), false);
  assert.equal(pairingPresentation({
    ok: false,
    stage: "transport",
    category: "timeout",
    reason: "device:timeout",
  }, 1, 3).done, false);
  assert.equal(pairingPresentation({
    ok: false,
    stage: "transport",
    category: "timeout",
    reason: "device:timeout",
  }, 3, 3).view.result, "phone-unreachable");
  assert.equal(pairingPresentation({ ok: true, stage: "prepared" }, 2, 3).view.result, "verified");

  const down = createMemoryTextStore();
  let attempts = 0;
  const unreachable = await confirmPairing({
    attempts: 3,
    wait: () => Promise.resolve(),
    loadInstallation: () => ({ ok: true, id: installation, reason: "" }),
    requestStore: down,
    allocate: () => "44444444-4444-4444-8444-444444444444",
    admission: { receive() { return {}; }, loadDurable() { return {}; } },
    request: () => {
      attempts += 1;
      return Promise.reject(new Error("socket hang up"));
    },
  });
  assert.equal(attempts, 3);
  assert.equal(unreachable.result, "phone-unreachable");
  assert.equal(unreachable.attempts, 3);
  const first = JSON.parse(down.raw);
  assert.equal(first.requestId, "44444444-4444-4444-8444-444444444444");

  const kept = createMemoryTextStore();
  let refusals = 0;
  const writer = await confirmPairing({
    attempts: 3,
    wait: () => Promise.resolve(),
    loadInstallation: () => ({ ok: true, id: installation, reason: "" }),
    requestStore: kept,
    allocate: () => "55555555-5555-4555-8555-555555555555",
    admission: { receive() { return {}; }, loadDurable() { return {}; } },
    request: () => {
      refusals += 1;
      return Promise.resolve({
        disposition: "refused",
        reason: "installation",
        hop: "bridge",
        category: "http-refusal",
      });
    },
  });
  assert.equal(refusals, 1);
  assert.equal(writer.result, "writer-kept");
});
