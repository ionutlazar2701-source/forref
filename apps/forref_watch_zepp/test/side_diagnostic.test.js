import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { BUILD_CODE, BUILD_NAME, BUILD_REV, BUILD_VERSION } from "../utils/build_stamp.js";
import {
  GET_SIDE_BUILD_V1,
  PROBE_BODY,
  PROBE_BRIDGE_V1,
  PROVISION_BRIDGE_URL,
  describeFetchException,
  probeBridge,
  runSideDiagnostic,
  sameBuild,
  sideBuildRecord,
} from "../utils/provision_bridge.js";

const appJson = JSON.parse(readFileSync(new URL("../app.json", import.meta.url), "utf8"));

function untouched() {
  return {
    requestStore: {
      read() {
        throw new Error("correlation-read");
      },
      write() {
        throw new Error("correlation-write");
      },
    },
    admission: {
      receive() {
        throw new Error("admission-write");
      },
      activate() {
        throw new Error("activation");
      },
      loadDurable() {
        throw new Error("admission-read");
      },
    },
    loadInstallation: () => {
      throw new Error("installation");
    },
  };
}

test("the device and side identity is the manifest version", () => {
  assert.equal(BUILD_VERSION, appJson.app.version.name);
  assert.equal(BUILD_CODE, appJson.app.version.code);
  assert.equal(BUILD_NAME, "com-004r-identity");
  assert.equal(BUILD_REV.length > 8, true);
  const record = sideBuildRecord();
  assert.equal(sameBuild(record), true);
  assert.equal(sameBuild({ ...record, code: String(BUILD_CODE) }), true);
  assert.equal(sameBuild({ disposition: "side-build", build: "com-003-prepare", rev: BUILD_REV, version: "1.0.25", code: 25 }), false);
  assert.equal(sameBuild({ disposition: "refused", reason: "method" }), false);
});

test("a stale side answer stops before the HTTP probe and writes nothing", async () => {
  const calls = [];
  const result = await runSideDiagnostic({
    ...untouched(),
    request(message) {
      calls.push(message.method);
      return Promise.resolve({ disposition: "refused", reason: "method", durable: false });
    },
  });
  assert.deepEqual(calls, [GET_SIDE_BUILD_V1]);
  assert.equal(result.ok, false);
  assert.equal(result.stage, "parity");
  assert.equal(result.reason, "parity:method");
  assert.equal(result.durable, false);
});

test("matching builds probe the bridge without a provision body", async () => {
  const calls = [];
  const result = await runSideDiagnostic({
    ...untouched(),
    request(message) {
      calls.push(message);
      if (message.method === GET_SIDE_BUILD_V1) return Promise.resolve(sideBuildRecord());
      return Promise.resolve({
        disposition: "probe",
        hop: "bridge",
        category: "answered",
        http: 409,
        reason: "message",
        detail: "",
        durable: false,
      });
    },
  });
  assert.equal(calls.length, 2);
  assert.equal(calls[0].method, GET_SIDE_BUILD_V1);
  assert.deepEqual(calls[0].params, {});
  assert.equal(calls[1].method, PROBE_BRIDGE_V1);
  assert.equal(sameBuild(calls[1].params), true);
  assert.equal(result.ok, true);
  assert.equal(result.reason, "probe:message");
  assert.equal(result.http, 409);
  assert.equal(result.durable, false);
});

test("the probe keeps the fetch exception and posts only the probe token", async () => {
  const error = new Error("Failed to fetch: cleartext communication to 127.0.0.1 not permitted by network security policy");
  error.name = "TypeError";
  error.code = "CLEARTEXT";
  const described = describeFetchException(error);
  assert.equal(described.name, "TypeError");
  assert.equal(described.code, "CLEARTEXT");
  assert.equal(described.message.includes("cleartext"), true);
  let options = null;
  const result = await probeBridge((given) => {
    options = given;
    return Promise.reject(error);
  });
  assert.equal(options.url, PROVISION_BRIDGE_URL);
  assert.equal(options.method, "POST");
  assert.equal(options.body, PROBE_BODY);
  assert.equal(options.body.includes("canonical"), false);
  assert.equal(options.body.includes("matchId"), false);
  assert.equal(options.body.includes("installationId"), false);
  assert.equal(result.category, "transport");
  assert.equal(result.reason, "transport");
  assert.equal(result.detail.includes("TypeError"), true);
  assert.equal(result.detail.includes("CLEARTEXT"), true);
  assert.equal(result.detail.includes("cleartext communication"), true);
  assert.equal(result.durable, false);
  const answered = await probeBridge(() => Promise.resolve({
    status: 409,
    body: JSON.stringify({ disposition: "refused", reason: "message", saved: false, d1Certified: false }),
  }));
  assert.equal(answered.category, "answered");
  assert.equal(answered.http, 409);
  assert.equal(answered.reason, "message");
  assert.equal(answered.detail, "");
});
