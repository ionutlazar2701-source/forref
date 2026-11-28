import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  installationLineFits,
  installationLineSize,
  resolveInstallationCard,
  splitInstallationId,
} from "../utils/installation_label.js";

const home = readFileSync(new URL("../page/gt/home/index.page.js", import.meta.url), "utf8");
const settings = readFileSync(new URL("../page/gt/settings/index.page.js", import.meta.url), "utf8");
const provision = readFileSync(new URL("../page/gt/provision/index.page.js", import.meta.url), "utf8");
const bip6 = { width: 390, height: 450, round: false };
const installationId = "6f1e2d3c-4b5a-4678-9abc-def012345678";

test("Home → Settings → Provision → Back keeps officiate and training", () => {
  assert.equal(home.includes('push({ url: "page/gt/select/index.page" })'), true);
  assert.equal(home.includes('push({ url: "page/gt/train/index.page" })'), true);
  assert.equal(home.includes('push({ url: "page/gt/settings/index.page" })'), true);
  assert.equal(home.includes("home-officiate"), true);
  assert.equal(home.includes("home-train"), true);
  assert.equal(home.includes("home-settings"), true);
  assert.equal(settings.includes('push({ url: "page/gt/provision/index.page" })'), true);
  assert.equal(settings.includes("settings-provision"), true);
  assert.equal(settings.includes("settings-back"), true);
  assert.equal(settings.includes("back()"), true);
  assert.equal(provision.includes("BasePage"), false);
  assert.equal(provision.includes("provision-back"), true);
  assert.equal(provision.includes("back()"), true);
  assert.equal(provision.includes("prepareInstallation"), true);
  assert.equal(provision.includes("installationUnavailable"), true);
  assert.equal(provision.includes("page=build"), true);
  const startAt = provision.indexOf("start() {");
  const handshakeAt = provision.indexOf("runPrepare({");
  assert.equal(handshakeAt > startAt, true);
  assert.equal(provision.includes("runHandshake"), false);
});

test("the provision screen shows all 36 installation characters on Bip 6", () => {
  const lines = splitInstallationId(installationId);
  assert.equal(installationId.length, 36);
  assert.equal(lines.join(""), installationId);
  assert.equal(lines.length, 2);
  const card = resolveInstallationCard(bip6);
  assert.equal(card.fallback, undefined);
  assert.equal(card.line.ok, true);
  assert.equal(card.line2.ok, true);
  assert.equal(card.back.ok, true);
  const size = installationLineSize(card.line.w, card.line.h, lines[0]);
  assert.equal(size >= 24, true);
  assert.equal(installationLineFits(card.line.w, lines[0], size), true);
  assert.equal(installationLineFits(card.line2.w, lines[1], size), true);
  assert.equal(card.line.y + card.line.h <= card.line2.y, true);
  assert.equal(card.back.y + card.back.h <= bip6.height - 2, true);
});
