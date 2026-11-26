import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  PHONE_OBSERVE,
  decodeAnchor,
  encodeAnchor,
  formatLife,
  formatPhone,
  formatUnknown,
  notePhoneEvent,
  sealFromSession,
} from "../utils/clock_phone_diag.js";

const session = {
  engine: "utc_segment",
  trust: "OBSERVED_UNVERIFIED",
  openStartUtc: 1700000000000,
  lastUtc: 1700000005000,
  firstHalfClosedMs: 0,
  secondHalfClosedMs: 0,
  seq: 4,
  epoch: "epoch-a",
  phase: "FIRST_HALF_RUNNING",
};

test("the diagnostic build observes the callback and still contains the fail-closed path", () => {
  assert.equal(PHONE_OBSERVE, true);
  const live = readFileSync(new URL("../utils/live_session.js", import.meta.url), "utf8");
  const device = readFileSync(new URL("../utils/clock_device.js", import.meta.url), "utf8");
  const segment = readFileSync(new URL("../utils/clock_segment.js", import.meta.url), "utf8");
  const page = readFileSync(new URL("../page/gt/live/index.page.js", import.meta.url), "utf8");
  assert.equal(device.includes("onPhoneTimeSetting"), true);
  assert.equal(live.includes("noteDiscontinuity"), true);
  assert.equal(live.includes("PHONE_OBSERVE"), true);
  assert.equal(live.includes("formatUnknown"), true);
  assert.equal(segment.includes("forref_clock006_anchor"), false);
  assert.equal(page.includes("phoneObserveWarn"), true);
  assert.equal(page.includes("live-build"), true);
  assert.equal(page.includes("live-destroy"), true);
});

test("a phone-time note keeps the last valid anchor and does not invent one", () => {
  const sealed = sealFromSession(session);
  assert.equal(sealed.openStartUtc, 1700000000000);
  const noted = notePhoneEvent(sealed, 1700000060000);
  assert.equal(noted.openStartUtc, 1700000000000);
  assert.equal(noted.lastUtc, 1700000005000);
  assert.equal(noted.phoneCount, 1);
  assert.equal(noted.phoneUtc, 1700000060000);
  const again = notePhoneEvent(noted, 1700000062000);
  assert.equal(again.openStartUtc, 1700000000000);
  assert.equal(again.phoneCount, 2);
  const bare = notePhoneEvent(null, 1700000062000);
  assert.equal(bare.openStartUtc, null);
  assert.equal(bare.phoneUtc, 1700000062000);
  const round = decodeAnchor(encodeAnchor(again));
  assert.equal(round.openStartUtc, again.openStartUtc);
  assert.equal(round.lastUtc, again.lastUtc);
  assert.equal(round.seq, 4);
  assert.equal(round.phoneCount, 2);
  assert.equal(sealFromSession({ engine: "utc_segment", trust: "TIME_UNVERIFIED", openStartUtc: 1 }), null);
});

test("phone and unknown lines carry the callback facts", () => {
  const phone = formatPhone({
    observe: true,
    utc: 1700000060000,
    anchor: 1700000005000,
    open: 1700000000000,
    epoch: "epoch-a",
    seq: 4,
    phase: "FIRST_HALF_RUNNING",
    trust: "OBSERVED_UNVERIFIED",
    screen: "on",
  });
  assert.equal(phone.includes("source=onPhoneTimeSetting"), true);
  assert.equal(phone.includes("mode=observe"), true);
  assert.equal(phone.includes("utc=1700000060000"), true);
  assert.equal(phone.includes("anchor=1700000005000"), true);
  assert.equal(phone.includes("open=1700000000000"), true);
  assert.equal(phone.includes("epoch=epoch-a"), true);
  assert.equal(phone.includes("seq=4"), true);
  const unknown = formatUnknown({
    reason: "BACKWARD",
    utc: 1699999990000,
    anchor: 1700000005000,
    open: 1700000000000,
    epoch: "epoch-b",
    seq: 5,
    persist: "SLOT_A",
  });
  assert.equal(unknown.includes("reason=BACKWARD"), true);
  assert.equal(unknown.includes("persist=SLOT_A"), true);
  assert.equal(unknown.includes("epoch=epoch-b"), true);
  assert.equal(formatLife("onCreate", { epoch: "epoch-b", utc: 10 }).includes("kind=onCreate"), true);
  const enforce = formatPhone({ observe: false, utc: 1, anchor: 1, open: 1, epoch: "e", seq: 1 });
  assert.equal(enforce.includes("mode=enforce"), true);
});
