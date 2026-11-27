import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { ACCENT, CANVAS, ROLES, TEXT_PRIMARY, TEXT_SECONDARY, TEXT_WARNING, styleFor } from "../utils/theme.js";
import { layoutEvent, layoutLive } from "../utils/geometry.js";

const root = new URL("..", import.meta.url);
const appJson = JSON.parse(readFileSync(new URL("../app.json", import.meta.url), "utf8"));
const chrome = readFileSync(new URL("../utils/chrome.js", import.meta.url), "utf8");
const live = readFileSync(new URL("../page/gt/live/index.page.js", import.meta.url), "utf8");
const controls = readFileSync(new URL("../page/gt/controls/index.page.js", import.meta.url), "utf8");
const eventPage = readFileSync(new URL("../page/gt/event/index.page.js", import.meta.url), "utf8");

const ROUTES = [
  "page/gt/home/index.page",
  "page/gt/select/index.page",
  "page/gt/hub/index.page",
  "page/gt/warmup/index.page",
  "page/gt/incident/index.page",
  "page/gt/ready/index.page",
  "page/gt/toss/index.page",
  "page/gt/live/index.page",
  "page/gt/controls/index.page",
  "page/gt/display/index.page",
  "page/gt/event/index.page",
  "page/gt/player/index.page",
  "page/gt/review/index.page",
  "page/gt/settings/index.page",
  "page/gt/provision/index.page",
  "page/gt/cautions/index.page",
  "page/gt/neutral/index.page",
  "page/gt/halftime/index.page",
  "page/gt/recovery/index.page",
  "page/gt/finish/index.page",
  "page/gt/train/index.page",
  "page/gt/train-warm/index.page",
  "page/gt/train-live/index.page",
  "page/gt/train-done/index.page",
];

const PROTECTED = [
  "utils/match_clock.js",
  "utils/clock_segment.js",
  "utils/clock_cadence.js",
  "utils/live_session.js",
  "utils/telemetry.js",
  "utils/telemetry_host.js",
  "utils/telemetry_bind.js",
  "utils/telemetry_store.js",
  "utils/geometry.js",
  "utils/text.js",
  "utils/state.js",
  "utils/abandon_arm.js",
  "utils/capture_candidate.js",
  "utils/capture_device.js",
  "utils/capture_storage.js",
  "utils/watch_provision.js",
  "utils/sha256_hex.js",
  "utils/goal_journal.js",
  "utils/local_test_score.js",
  "utils/installation_id.js",
  "utils/provision_transport.js",
  "utils/goal_admission.js",
  "utils/goal_capture.js",
  "utils/provision_bridge.js",
];

function lin(channel) {
  const c = channel / 255;
  return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
}

function luminance(hex) {
  const r = (hex >> 16) & 255;
  const g = (hex >> 8) & 255;
  const b = hex & 255;
  return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
}

function contrast(fg, bg) {
  const a = luminance(fg);
  const b = luminance(bg);
  const light = Math.max(a, b);
  const dark = Math.min(a, b);
  return (light + 0.05) / (dark + 0.05);
}

function walk(dir, out) {
  for (const name of readdirSync(dir)) {
    if (name === "node_modules" || name === "dist" || name === "test") {
      continue;
    }
    const path = join(dir, name);
    if (statSync(path).isDirectory()) {
      walk(path, out);
    } else if (name.endsWith(".js")) {
      out.push(path);
    }
  }
  return out;
}

test("the app canvas is exact black and the old full-screen navy is gone", () => {
  assert.equal(CANVAS, 0x000000);
  assert.equal(chrome.includes("color: CANVAS"), true);
  assert.equal(chrome.includes("0x071d33"), false);
  assert.equal(chrome.includes("0x0b2d5b"), false);
  assert.equal(chrome.includes("press_color: 0x3fc3be"), false);
  const sources = walk(new URL("../page", import.meta.url).pathname, []);
  for (const path of sources) {
    const source = readFileSync(path, "utf8");
    assert.equal(source.includes("0x071d33"), false, path);
    assert.equal(source.includes("0x0b2d5b"), false, path);
    assert.equal(/0x[0-9a-fA-F]{3,8}/.test(source), false, path);
    assert.equal(source.includes("stack(") || source.includes("paintBase("), true, path);
  }
});

test("filled turquoise and blue keep black labels in both states", () => {
  for (const name of ["primary", "navigation", "selected"]) {
    const role = ROLES[name];
    assert.equal(role.text, 0x000000, name);
    assert.notEqual(role.normal, role.press, name);
    assert.ok(contrast(role.text, role.normal) >= 4.5, name + " rest " + contrast(role.text, role.normal));
    assert.ok(contrast(role.text, role.press) >= 4.5, name + " press " + contrast(role.text, role.press));
  }
  for (const name of ["yellow", "red", "caution", "neutral"]) {
    const role = ROLES[name];
    assert.equal(role.text, TEXT_PRIMARY, name);
    assert.notEqual(role.normal, role.press, name);
    assert.ok(contrast(role.text, role.normal) >= 4.5, name + " rest " + contrast(role.text, role.normal));
    assert.ok(contrast(role.text, role.press) >= 4.5, name + " press " + contrast(role.text, role.press));
  }
  assert.equal(styleFor(undefined).normal, ROLES.navigation.normal);
  assert.equal(styleFor(0x0b2d5b).normal, ROLES.navigation.normal);
  assert.notEqual(ROLES.yellow.normal, ROLES.red.normal);
  assert.notEqual(ROLES.yellow.normal, ROLES.caution.normal);
  assert.notEqual(ROLES.red.normal, ROLES.caution.normal);
  assert.equal(TEXT_WARNING, 0xc4a35a);
  assert.notEqual(TEXT_WARNING, ACCENT);
  assert.equal(TEXT_SECONDARY, 0xb3cbd7);
  assert.ok(contrast(TEXT_SECONDARY, CANVAS) >= 4.5);
  assert.ok(contrast(TEXT_WARNING, CANVAS) >= 4.5);
  assert.ok(contrast(TEXT_PRIMARY, CANVAS) >= 7);
});

test("the manifest still has the 24 current routes and each one paints through the shared shell", () => {
  assert.deepEqual(appJson.targets.gt.module.page.pages, ROUTES);
  assert.equal(appJson.app.appId, 29566);
  assert.equal(appJson.app.version.name, "1.0.17");
  assert.equal(appJson.app.version.code, 17);
  for (const route of ROUTES) {
    const source = readFileSync(new URL("../" + route + ".js", import.meta.url), "utf8");
    assert.equal(source.includes("stack(") || source.includes("paintBase("), true, route);
  }
});

test("sporting roles stay distinct and unverified time is not painted as turquoise", () => {
  assert.equal(live.includes('return "red"'), true);
  assert.equal(live.includes('return "caution"'), true);
  assert.equal(live.includes('return "primary"'), true);
  assert.equal(live.includes("view.unverified ? TEXT_WARNING : ACCENT"), true);
  assert.equal(live.includes('"neutral"'), true);
  assert.equal(controls.includes('return "red"'), true);
  assert.equal(controls.includes('return "caution"'), true);
  assert.equal(controls.includes("TEXT_WARNING"), true);
  assert.equal(eventPage.includes('"yellow"'), true);
  assert.equal(eventPage.includes('"red"'), true);
  assert.equal(eventPage.includes('"neutral"'), true);
  assert.equal(live.includes("formatTelemetryLine"), true);
  assert.equal(live.includes("pulseTelemetry"), true);
});

test("clock, telemetry, geometry, and copy modules do not take the theme", () => {
  for (const path of PROTECTED) {
    const source = readFileSync(new URL("../" + path, import.meta.url), "utf8");
    assert.equal(source.includes("utils/theme"), false, path);
    assert.equal(source.includes("0x071d33"), false, path);
  }
});

test("live A/C and event hit rectangles are unchanged on rect and round", () => {
  const rect = { width: 390, height: 450, round: false };
  const round = { width: 480, height: 480, round: true };
  assert.deepEqual(layoutLive(rect, "A"), {
    phaseY: 70,
    timeY: 108,
    home: { x: 10, y: 196, w: 181, h: 108, ok: true },
    away: { x: 199, y: 196, w: 181, h: 108, ok: true },
    display: { x: 10, y: 392, w: 181, h: 46, ok: true },
    back: { x: 199, y: 392, w: 181, h: 46, ok: true },
  });
  assert.deepEqual(layoutLive(round, "A"), {
    phaseY: 52,
    timeY: 96,
    home: { x: 70, y: 188, w: 166, h: 100, ok: true },
    away: { x: 244, y: 188, w: 166, h: 100, ok: true },
    display: { x: 70, y: 328, w: 166, h: 46, ok: true },
    back: { x: 244, y: 328, w: 166, h: 46, ok: true },
  });
  assert.deepEqual(layoutLive(rect, "C"), {
    phaseY: 168,
    timeY: 204,
    home: { x: 10, y: 72, w: 370, h: 80, ok: true },
    away: { x: 10, y: 260, w: 370, h: 80, ok: true },
    display: { x: 10, y: 394, w: 181, h: 44, ok: true },
    back: { x: 199, y: 394, w: 181, h: 44, ok: true },
  });
  assert.deepEqual(layoutLive(round, "C"), {
    phaseY: 146,
    timeY: 184,
    home: { x: 103, y: 58, w: 274, h: 72, ok: true },
    away: { x: 103, y: 250, w: 274, h: 72, ok: true },
    display: { x: 103, y: 352, w: 133, h: 44, ok: true },
    back: { x: 244, y: 352, w: 133, h: 44, ok: true },
  });
  assert.deepEqual(layoutEvent(rect).yellow, { x: 73, y: 92, w: 118, h: 118, ok: true });
  assert.deepEqual(layoutEvent(rect).red, { x: 199, y: 92, w: 118, h: 118, ok: true });
  assert.deepEqual(layoutEvent(round).goal, { x: 108, y: 214, w: 128, h: 128, ok: true });
  assert.equal(root.pathname.includes("forref_watch_zepp"), true);
});
