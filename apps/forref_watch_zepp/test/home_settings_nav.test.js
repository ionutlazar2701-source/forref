import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { layoutStack } from "../utils/geometry.js";
import {
  installationLineFits,
  installationLineSize,
  provisionIdentityRows,
  splitInstallationId,
} from "../utils/installation_label.js";

const home = readFileSync(new URL("../page/gt/home/index.page.js", import.meta.url), "utf8");
const settings = readFileSync(new URL("../page/gt/settings/index.page.js", import.meta.url), "utf8");
const provision = readFileSync(new URL("../page/gt/provision/index.page.js", import.meta.url), "utf8");
const label = readFileSync(new URL("../utils/installation_label.js", import.meta.url), "utf8");
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
  assert.equal(label.includes('name: "provision-back"'), true);
  assert.equal(provision.includes('row.action === "back"'), true);
  assert.equal(provision.includes("back()"), true);
  assert.equal(provision.includes("provisionIdentityRows"), true);
  assert.equal(provision.includes("loadInstallationId"), true);
  const startAt = provision.indexOf("start() {");
  const handshakeAt = provision.indexOf("runHandshake({");
  assert.equal(handshakeAt > startAt, true);
});

test("the provision screen shows all 36 installation characters on Bip 6", () => {
  const lines = splitInstallationId(installationId);
  assert.equal(installationId.length, 36);
  assert.equal(lines.join(""), installationId);
  assert.equal(lines.length, 2);
  const rows = provisionIdentityRows(
    { installationId: installationId, stage: "identity" },
    {
      missing: "INSTALLATION REQUIRED",
      stage: "INSTALLATION READY",
      match: "MATCH",
      teams: "— — —",
      transport: "TRANSPORT ",
      d1: "D1 UNCERTIFIED",
      provision: "PROVISION",
      back: "BACK",
    },
  );
  const shown = rows.filter((row) => row.fitText).map((row) => row.label);
  assert.deepEqual(shown, lines);
  assert.equal(shown.join("").length, 36);
  const laid = layoutStack(bip6, rows.length);
  assert.equal(laid.rows.length, rows.length);
  shown.forEach((line, index) => {
    const slot = laid.rows[index];
    assert.equal(slot.ok, true);
    const size = installationLineSize(slot.w, slot.h, line);
    assert.equal(size >= 24, true);
    assert.equal(installationLineFits(slot.w, line, size), true);
    assert.equal(line.length * 0.62 * size <= slot.h || size <= slot.h - 4, true);
  });
  assert.equal(rows[rows.length - 1].action, "back");
  assert.equal(rows.some((row) => row.action === "start"), true);
  const missing = provisionIdentityRows(null, {
    missing: "INSTALLATION REQUIRED",
    stage: "NONE",
    match: "MATCH",
    teams: "— — —",
    transport: "TRANSPORT ",
    d1: "D1",
    provision: "PROVISION",
    back: "BACK",
  });
  assert.equal(missing.some((row) => row.label === installationId), false);
  assert.equal(missing[0].label, "INSTALLATION REQUIRED");
});
