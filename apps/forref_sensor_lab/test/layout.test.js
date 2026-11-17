import test from "node:test";
import assert from "node:assert/strict";
import { layoutLab, rowFits } from "../lib/layout.js";

test("the Bip 6 stack stays below the status bar", () => {
  const info = { width: 390, height: 450, round: false, screenShape: 0 };
  const laid = layoutLab(info, 8);
  assert.ok(laid.rowH >= 28);
  for (let i = 0; i < laid.rows.length; i++) {
    assert.equal(rowFits(info, laid.rows[i]), true, "row " + i);
  }
});
