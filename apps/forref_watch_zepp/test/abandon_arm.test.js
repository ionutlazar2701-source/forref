import test from "node:test";
import assert from "node:assert/strict";
import { createAbandonArm } from "../utils/abandon_arm.js";

const SUSPENDED = "controls|FIRST_HALF_SUSPENDED";

test("the second tap confirms only while the same context stays armed", () => {
  const arm = createAbandonArm();
  assert.equal(arm.confirmed(SUSPENDED), false);
  arm.arm(SUSPENDED);
  assert.equal(arm.armed(), true);
  assert.equal(arm.confirmed(SUSPENDED), true);
  assert.equal(arm.armed(), false);
  assert.equal(arm.confirmed(SUSPENDED), false);
});

test("navigation, back, and page exit disarm the confirmation", () => {
  for (const reason of ["navigate", "back", "exit"]) {
    const arm = createAbandonArm();
    arm.arm(SUSPENDED);
    const result = arm.disarm(reason);
    assert.equal(result.disarmed, true);
    assert.equal(result.reason, reason);
    assert.equal(arm.armed(), false);
    assert.equal(arm.confirmed(SUSPENDED), false);
  }
});

test("a changed phase or mode disarms before the next tap can confirm", () => {
  const arm = createAbandonArm();
  arm.arm(SUSPENDED);
  const phase = arm.retain("controls|SECOND_HALF_SUSPENDED");
  assert.equal(phase.reason, "context");
  assert.equal(arm.armed(), false);
  arm.arm("A|FIRST_HALF_SUSPENDED");
  const mode = arm.retain("C|FIRST_HALF_SUSPENDED");
  assert.equal(mode.disarmed, true);
  assert.equal(arm.confirmed("C|FIRST_HALF_SUSPENDED"), false);
});

test("a disarmed latch arms again instead of confirming", () => {
  const arm = createAbandonArm();
  arm.arm(SUSPENDED);
  arm.disarm("navigate");
  assert.equal(arm.confirmed(SUSPENDED), false);
  arm.arm(SUSPENDED);
  assert.equal(arm.confirmed(SUSPENDED), true);
});
