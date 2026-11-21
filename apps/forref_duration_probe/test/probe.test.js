import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { layoutProbe, rowFits } from "../lib/layout.js";
import { lines, tables } from "../utils/text.js";
import { initialProbe } from "../../forref_sensor_lab/lib/native_elapsed.js";

test("eight probe rows fit the Bip 6 rect", () => {
  const info = { width: 390, height: 450, round: false, screenShape: 0 };
  const laid = layoutProbe(info, 8);
  assert.ok(laid.rowH >= 28);
  for (let i = 0; i < laid.rows.length; i += 1) {
    assert.equal(rowFits(info, laid.rows[i]), true, "row " + i);
  }
});

test("Romanian covers every English label and a reading stays unproven", () => {
  const keys = Object.keys(tables().EN);
  for (let i = 0; i < keys.length; i += 1) {
    assert.equal(typeof tables().RO[keys[i]], "string", keys[i]);
  }
  const state = initialProbe();
  state.status = "TIME_UNKNOWN";
  state.reason = "DISPLAY_STRING_NOT_ELAPSED";
  state.durationText = "1:05:34";
  state.referee = "65:34";
  state.permission = 2;
  state.permissionReason = "AUTHORIZED";
  const rendered = lines(state, 21);
  assert.equal(rendered[0].text.indexOf("Permisiune") >= 0, true);
  assert.equal(rendered[5].text.indexOf("TIME_UNKNOWN") >= 0, true);
  assert.equal(rendered[5].text.indexOf("65:34") >= 0, true);
  assert.equal(rendered[5].text.indexOf("PROVEN_TIME") >= 0, false);
  const page = readFileSync(new URL("../page/gt/home/index.page.js", import.meta.url), "utf8");
  assert.equal(page.includes("return getSportData(options, callback)"), true);
  assert.equal(page.includes("queryPermission({ permissions: [WORKOUT_PERMISSION] })"), true);
});
