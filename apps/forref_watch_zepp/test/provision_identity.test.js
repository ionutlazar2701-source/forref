import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { messagingReady, prepareInstallation, readDeviceMessaging } from "../utils/provision_identity.js";
import { resolveInstallationCard } from "../utils/installation_label.js";

const installationId = "6f1e2d3c-4b5a-4678-9abc-def012345678";
const page = readFileSync(new URL("../page/gt/provision/index.page.js", import.meta.url), "utf8");
const app = readFileSync(new URL("../app.js", import.meta.url), "utf8");

function store(initial) {
  return {
    raw: initial,
    writes: 0,
    fail: false,
    unreadable: false,
    read() {
      if (this.fail) throw new Error("disk");
      if (this.unreadable) return { status: "unreadable" };
      if (this.raw == null) return { status: "absent", text: "" };
      return { status: "ok", text: this.raw };
    },
    write(text) {
      this.writes += 1;
      this.raw = text;
      return { status: "ok", text: text };
    },
  };
}

test("a plain globalData has no messaging until the device app attaches it", () => {
  const globalData = { demo: true };
  assert.equal(messagingReady(globalData), false);
  assert.throws(() => globalData.messaging.onCall(), TypeError);
  assert.equal(readDeviceMessaging({ _options: { globalData } }), null);
  const messaging = {
    onCall() {
      return this;
    },
    request() {
      return Promise.resolve(null);
    },
  };
  globalData.messaging = messaging;
  assert.equal(messagingReady(globalData), true);
  assert.equal(readDeviceMessaging({ globalData }), messaging);
  assert.equal(readDeviceMessaging({ _options: { globalData: { demo: true } }, globalData }), messaging);
  assert.equal(app.includes('from "@zeppos/zml'), false);
  assert.equal(app.includes("App({"), true);
  assert.equal(app.includes("openDeviceApp"), false);
  assert.equal(app.includes("startForegroundClock"), true);
  assert.equal(app.includes("setWakeUpRelaunch"), true);
  assert.equal(page.includes("BasePage"), false);
  assert.equal(page.includes("messagingReady"), false);
  assert.equal(page.includes('from "@zeppos/zml/3.0/module/messaging/plugin/app"'), true);
  assert.equal(page.includes("base-app"), false);
  assert.equal(page.includes("prepareInstallation"), true);
  assert.equal(page.indexOf("prepareInstallation") < page.indexOf("runSideDiagnostic({"), true);
  assert.equal(page.includes("runHandshake"), false);
  assert.equal(page.includes("readProvisionEvidence"), true);
  assert.equal(page.includes("SUBMIT_WATCH_LOCK_V1"), false);
});

test("a valid installation id is shown again and is not rewritten", () => {
  const kept = store(installationId);
  const first = prepareInstallation(kept);
  const second = prepareInstallation(kept);
  assert.equal(first.ok, true);
  assert.equal(first.created, false);
  assert.equal(first.id, installationId);
  assert.equal(second.id, first.id);
  assert.equal(kept.writes, 0);
  assert.equal(kept.raw, installationId);
});

test("a missing installation is created once and then reused", () => {
  const fresh = store(null);
  const created = prepareInstallation(fresh);
  const again = prepareInstallation(fresh);
  assert.equal(created.ok, true);
  assert.equal(created.created, true);
  assert.equal(created.id.length, 36);
  assert.equal(again.id, created.id);
  assert.equal(again.created, false);
  assert.equal(fresh.writes, 1);
});

test("storage failure is explicit and does not replace a stored id", () => {
  const torn = store("not-a-uuid");
  const corrupt = prepareInstallation(torn);
  assert.equal(corrupt.ok, false);
  assert.equal(corrupt.reason, "corrupt");
  assert.equal(torn.writes, 0);
  assert.equal(torn.raw, "not-a-uuid");
  const blocked = store(installationId);
  blocked.unreadable = true;
  const unread = prepareInstallation(blocked);
  assert.equal(unread.ok, false);
  assert.equal(unread.reason, "unreadable");
  assert.equal(blocked.writes, 0);
  const disk = store(installationId);
  disk.fail = true;
  const exploded = prepareInstallation(disk);
  assert.equal(exploded.ok, false);
  assert.equal(exploded.reason, "exception");
  assert.equal(disk.writes, 0);
  assert.equal(page.includes("installationUnavailable"), true);
});

test("a card that does not fit still resolves to a drawable fallback", () => {
  const tiny = { width: 80, height: 80, round: false };
  const card = resolveInstallationCard(tiny);
  assert.equal(card.fallback, true);
  assert.equal(card.line.h > 0, true);
  assert.equal(card.line2.h > 0, true);
  assert.equal(card.back.h > 0, true);
});
