import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const home = readFileSync(new URL("../page/gt/home/index.page.js", import.meta.url), "utf8");
const copy = readFileSync(new URL("../utils/text.js", import.meta.url), "utf8");

test("home is the two Figma zones and keeps the existing routes", () => {
  assert.equal(home.includes("paintBase("), true);
  assert.equal(home.includes("layoutHome("), true);
  assert.equal(home.includes("page/gt/select/index.page"), true);
  assert.equal(home.includes("page/gt/train/index.page"), true);
  assert.equal(home.includes("settings"), false);
  assert.equal(home.includes("stack("), false);
  assert.equal(/0x[0-9a-fA-F]{3,8}/.test(home), false);
  assert.equal(home.includes("TEXT_PRIMARY"), true);
  assert.equal(home.includes("TEXT_SECONDARY"), true);
  assert.equal(home.includes("ACCENT"), true);
});

test("mode subtitles exist in English and Romanian", () => {
  assert.equal(copy.includes('officiateBody: "Start Match & Live Controls"'), true);
  assert.equal(copy.includes('trainHint: "Fitness & Drills Tracker"'), true);
  assert.equal(copy.includes('officiateBody: "Start meci și comenzi live"'), true);
  assert.equal(copy.includes('trainHint: "Fitness și exerciții"'), true);
  assert.equal(copy.includes('trainBody: "SEPARATE FROM THE MATCH."'), true);
  assert.equal(copy.includes('trainBody: "SEPARAT DE MECI."'), true);
});
