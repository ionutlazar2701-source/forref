import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { isPong, nextLinkSeq, pingRequest, replyLink } from "../utils/link_channel.js";

const page = readFileSync(new URL("../page/gt/link/index.page.js", import.meta.url), "utf8");
const side = readFileSync(new URL("../app-side/index.js", import.meta.url), "utf8");
const app = readFileSync(new URL("../app.js", import.meta.url), "utf8");
const provision = readFileSync(new URL("../page/gt/provision/index.page.js", import.meta.url), "utf8");
const settings = readFileSync(new URL("../page/gt/settings/index.page.js", import.meta.url), "utf8");

test("PING returns PONG with the same sequence and nothing else", () => {
  const ping = pingRequest(3);
  assert.deepEqual(ping, { method: "PING", params: { seq: 3 } });
  assert.equal(replyLink({ method: "GET_WATCH_PROVISION_V1", params: {} }), null);
  assert.equal(replyLink(null), null);
  assert.deepEqual(replyLink({ method: "PING", params: { seq: 0 } }), { error: "seq" });
  assert.deepEqual(replyLink({ method: "PING", params: { seq: 1.5 } }), { error: "seq" });
  assert.deepEqual(replyLink(ping), { body: { method: "PONG", seq: 3 } });
  assert.equal(isPong({ method: "PONG", seq: 3 }, 3), true);
  assert.equal(isPong({ method: "PONG", seq: 4 }, 3), false);
  assert.equal(isPong({ method: "PING", seq: 3 }, 3), false);
});

test("the sequence advances once per ping and stays on the running app", () => {
  const globalData = { demo: true, clockEpoch: "e1" };
  assert.equal(nextLinkSeq(globalData), 1);
  assert.equal(nextLinkSeq(globalData), 2);
  assert.equal(globalData.clockEpoch, "e1");
  assert.equal(globalData.demo, true);
});

test("the link page loads messaging on tap and the side answers before provision", () => {
  const buildAt = page.indexOf("build() {");
  const pingAt = page.indexOf("ping() {");
  assert.equal(buildAt > 0 && pingAt > buildAt, true);
  assert.equal(page.slice(buildAt, pingAt).includes("appPlugin"), false);
  assert.equal(page.slice(buildAt, pingAt).includes("attachDeviceMessaging"), false);
  assert.equal(page.includes('from "@zeppos/zml/3.0/module/messaging/plugin/app"'), true);
  assert.equal(page.includes("base-app"), false);
  assert.equal(page.includes("disConnect"), false);
  assert.equal(page.includes("runHandshake"), false);
  assert.equal(page.includes("page=build"), true);
  assert.equal(app.includes("App({"), true);
  assert.equal(app.includes("@zeppos/zml"), false);
  assert.equal(provision.includes("@zeppos/zml"), false);
  assert.equal(settings.includes('push({ url: "page/gt/link/index.page" })'), true);
  assert.equal(side.indexOf("replyLink") < side.indexOf("dispatchSideRequest"), true);
  assert.equal(side.includes("GET_WATCH_PROVISION_V1"), false);
});
