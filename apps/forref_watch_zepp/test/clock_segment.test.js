import test from "node:test";
import assert from "node:assert/strict";
import {
  DISPLAY_CONTINUITY_MS,
  Phase,
  REGULATION_HALF_MS,
  Trust,
  applyIntent,
  commitSession,
  displayText,
  freshSession,
  liveFrame,
  noteDiscontinuity,
  present,
} from "../utils/match_clock.js";
import { commitSegment, loadLiveClock, openUtcSession, readSegment } from "../utils/clock_segment.js";

const EPOCH = "epoch-a";
const T0 = 1700000000000;

function obs(utc, id) {
  return { utcMillis: utc, epoch: EPOCH, intentId: id };
}

function kick(at, halfLimitMs) {
  const started = applyIntent(openUtcSession(EPOCH, halfLimitMs), "KICK_OFF", obs(at, "kick"));
  assert.equal(started.ok, true);
  return started.session;
}

function show(session, utc, epoch) {
  const frame = liveFrame(session, utc, epoch || EPOCH);
  return { frame: frame, text: displayText(frame.view) };
}

function slots() {
  const box = { A: "", B: "", engine: "" };
  return {
    box: box,
    readA() {
      return box.A;
    },
    writeA(raw) {
      box.A = raw;
      return true;
    },
    readB() {
      return box.B;
    },
    writeB(raw) {
      box.B = raw;
      return true;
    },
    readEngine() {
      return box.engine;
    },
    writeEngine(raw) {
      box.engine = raw;
      return true;
    },
  };
}

function legacy() {
  const box = { file: "", kv: "", mirror: "" };
  return {
    box: box,
    writeFile(raw) {
      box.file = raw;
      return true;
    },
    readFile() {
      return box.file;
    },
    writeKv(raw) {
      box.kv = raw;
      return true;
    },
    readKv() {
      return box.kv;
    },
    writeMirror(raw) {
      box.mirror = raw;
      return true;
    },
    readMirror() {
      return box.mirror;
    },
  };
}

test("a paint refreshes digits from the UTC anchor and does not add a second", () => {
  const session = kick(T0);
  const first = show(session, T0 + 30000);
  assert.equal(first.text, "00:30");
  assert.equal(first.frame.admitted, true);
  assert.equal(first.frame.reason, "UTC_ASSUMED");
  assert.equal(first.frame.view.integrity, "UTC_ASSUMED");
  assert.equal(first.frame.session.lastUtc, T0);
  assert.equal(first.frame.session.seq, session.seq);
  assert.notEqual(first.frame.session.trust, Trust.UNVERIFIED);
  const second = show(first.frame.session, T0 + 31000);
  assert.equal(second.text, "00:31");
  assert.equal(second.frame.session.openStartUtc, T0);
});

test("sleep of 30 seconds, 2 minutes, 10 minutes, 45 minutes, and 90 minutes stays on the anchor", () => {
  const session = kick(T0);
  assert.equal(DISPLAY_CONTINUITY_MS, 2500);
  for (const gap of [30000, 120000, 600000, 45 * 60000, 90 * 60000]) {
    const frame = show(session, T0 + gap);
    assert.equal(frame.frame.reason, "UTC_ASSUMED", String(gap));
    assert.equal(frame.frame.view.integrity, "UTC_ASSUMED", String(gap));
    assert.notEqual(frame.frame.view.integrity, "TIME_UNKNOWN", String(gap));
    assert.equal(frame.frame.session.phase, Phase.FIRST_HALF_RUNNING, String(gap));
  }
  assert.equal(show(session, T0 + 30000).text, "00:30");
  assert.equal(show(session, T0 + 120000).text, "02:00");
  assert.equal(show(session, T0 + 600000).text, "10:00");
  assert.equal(show(session, T0 + 45 * 60000).text, "45:00");
  assert.equal(show(session, T0 + 90 * 60000).text, "45 + 45:00");
});

test("pause and resume exclude the paused gap, including a gap wider than the sampler window", () => {
  const running = kick(T0);
  const paused = applyIntent(running, "PAUSE", obs(T0 + 12 * 60000, "pause"));
  assert.equal(paused.ok, true, paused.reason);
  assert.equal(show(paused.session, T0 + 20 * 60000).text, "12:00");
  const resumed = applyIntent(paused.session, "RESUME", obs(T0 + 20 * 60000, "resume"));
  assert.equal(resumed.ok, true);
  assert.equal(show(resumed.session, T0 + 23 * 60000).text, "15:00");
  const again = applyIntent(paused.session, "PAUSE", obs(T0 + 20 * 60000, "pause-again"));
  assert.equal(again.ok, false);
  assert.equal(again.reason, "ILLEGAL");
});

test("half-time holds and the second half starts at the competition mark", () => {
  const running = kick(T0);
  const ended = applyIntent(running, "END_FIRST_HALF", obs(T0 + REGULATION_HALF_MS, "end-h1"));
  assert.equal(ended.ok, true, ended.reason);
  assert.equal(show(ended.session, T0 + REGULATION_HALF_MS + 15 * 60000).text, "45:00");
  assert.equal(ended.session.phase, Phase.HALF_TIME);
  const second = applyIntent(ended.session, "START_SECOND_HALF", obs(T0 + 60 * 60000, "h2"));
  assert.equal(second.ok, true);
  assert.equal(show(second.session, T0 + 60 * 60000).text, "45:00");
  assert.equal(show(second.session, T0 + 80 * 60000).text, "65:00");
  const full = applyIntent(second.session, "FULL_TIME", obs(T0 + 105 * 60000, "full"));
  assert.equal(full.ok, true, full.reason);
  assert.equal(show(full.session, T0 + 120 * 60000).text, "90:00");
});

test("a stored half length replaces the 45-minute display mark", () => {
  const limit = 40 * 60000;
  const running = kick(T0, limit);
  assert.equal(show(running, T0 + limit).text, "40:00");
  assert.equal(show(running, T0 + limit + 60000).text, "40 + 01:00");
  const ended = applyIntent(running, "END_FIRST_HALF", obs(T0 + limit, "end-40"));
  const second = applyIntent(ended.session, "START_SECOND_HALF", obs(T0 + limit + 60000, "h2-40"));
  assert.equal(show(second.session, T0 + limit + 60000).text, "40:00");
  assert.equal(show(second.session, T0 + limit + 21 * 60000).text, "60:00");
  assert.equal(show(second.session, T0 + 2 * limit + 3 * 60000).text, "80 + 02:00");
});

test("suspension excludes the stopped interval and additional time stays display-only", () => {
  const running = kick(T0);
  const suspended = applyIntent(running, "SUSPEND_GAME", obs(T0 + 10 * 60000, "suspend"));
  assert.equal(suspended.ok, true, suspended.reason);
  assert.equal(show(suspended.session, T0 + 18 * 60000).text, "10:00");
  const resumed = applyIntent(suspended.session, "RESUME_GAME", obs(T0 + 18 * 60000, "back"));
  assert.equal(resumed.ok, true);
  assert.equal(show(resumed.session, T0 + 20 * 60000).text, "12:00");
});

test("capture navigation does not reset or unknown a healthy segment", () => {
  let session = kick(T0);
  const pages = [5000, 20000, 45000, 90000];
  for (const gap of pages) {
    const frame = show(session, T0 + gap);
    assert.equal(frame.frame.session.phase, Phase.FIRST_HALF_RUNNING);
    assert.equal(frame.frame.view.integrity, "UTC_ASSUMED");
    session = frame.frame.session;
  }
  assert.equal(show(session, T0 + 90000).text, "01:30");
  assert.equal(session.openStartUtc, T0);
});

test("restart reads the anchor back from the dual slot", () => {
  const store = slots();
  const prior = legacy();
  const session = kick(T0);
  const saved = commitSegment(store, session);
  assert.equal(saved.ok, true, saved.reason);
  const before = store.box.A + store.box.B;
  show(session, T0 + 600000);
  assert.equal(store.box.A + store.box.B, before);
  const loaded = loadLiveClock(store, prior, EPOCH, T0 + 600000);
  assert.equal(loaded.reason.indexOf("SEGMENT_") === 0, true);
  assert.equal(show(loaded.session, T0 + 600000).text, "10:00");
  assert.equal(loaded.session.openStartUtc, T0);
});

test("torn slots and a same-seq conflict fail closed and do not fall through to a legacy match", () => {
  const store = slots();
  const prior = legacy();
  const session = kick(T0);
  commitSession(prior, session);
  const legacyBytes = prior.box.file;
  store.box.A = "{torn";
  store.box.B = "not-json";
  const broken = loadLiveClock(store, prior, EPOCH, T0 + 600000);
  assert.equal(broken.reason, "CORRUPT");
  assert.equal(broken.session.trust, Trust.UNVERIFIED);
  assert.equal(broken.session.integrity, "TIME_UNKNOWN");
  assert.equal(prior.box.file, legacyBytes);
  const kickoff = applyIntent(broken.session, "KICK_OFF", obs(T0 + 600000, "new"));
  assert.equal(kickoff.ok, false);
  assert.equal(kickoff.reason, "UNVERIFIED");

  const healthy = slots();
  commitSegment(healthy, session);
  const paused = applyIntent(session, "PAUSE", obs(T0 + 600000, "pause"));
  commitSegment(healthy, paused.session);
  healthy.box.B = "torn-slot";
  const recovered = readSegment(healthy);
  assert.equal(recovered.ok, true);
  assert.equal(recovered.session.phase, Phase.FIRST_HALF_PAUSED);
  assert.equal(show(recovered.session, T0 + 700000).text, "10:00");

  const conflict = slots();
  const one = slots();
  commitSegment(one, session);
  const two = slots();
  const other = kick(T0 + 1000);
  commitSegment(two, other);
  conflict.box.A = one.box.B;
  conflict.box.B = two.box.B;
  const clashed = loadLiveClock(conflict, prior, EPOCH, T0 + 600000);
  assert.equal(clashed.reason, "CONFLICT");
  assert.equal(clashed.session.trust, Trust.UNVERIFIED);
});

test("a repeated intent id is ignored and a second kick-off is illegal", () => {
  const session = kick(T0);
  const duplicate = applyIntent(session, "PAUSE", obs(T0 + 1000, "kick"));
  assert.equal(duplicate.duplicate, true);
  const again = applyIntent(session, "KICK_OFF", obs(T0 + 1000, "kick-2"));
  assert.equal(again.reason, "ILLEGAL");
});

test("a detected phone-time change fails closed without folding the open projection", () => {
  const session = kick(T0);
  assert.equal(show(session, T0 + 10 * 60000).text, "10:00");
  const jumped = noteDiscontinuity(session, T0 + 10 * 60000, "PHONE_TIME_SETTING");
  assert.equal(jumped.reason, "PHONE_TIME_SETTING");
  assert.equal(jumped.session.trust, Trust.UNVERIFIED);
  assert.equal(jumped.session.integrity, "TIME_UNKNOWN");
  assert.equal(jumped.session.firstHalfClosedMs, 0);
  assert.equal(present(jumped.session, T0 + 10 * 60000).digits, null);
  assert.equal(present(jumped.session, T0 + 10 * 60000).integrity, "TIME_UNKNOWN");
  const held = noteDiscontinuity(applyIntent(session, "PAUSE", obs(T0 + 60000, "pause")).session, T0 + 120000);
  assert.equal(held.reason, "HELD");
});

test("a backward clock and a segment outside the diagnostic window fail closed", () => {
  const session = kick(T0);
  const back = show(session, T0 - 1000);
  assert.equal(back.frame.reason, "BACKWARD");
  assert.equal(back.frame.session.trust, Trust.UNVERIFIED);
  assert.equal(back.text, null);
  const wide = show(session, T0 + 7 * 60 * 60 * 1000);
  assert.equal(wide.frame.reason, "SEGMENT_OUTSIDE_WINDOW");
  assert.equal(wide.frame.view.integrity, "TIME_UNKNOWN");
});

test("the sampler rollback still refuses an unsampled gap", () => {
  const started = applyIntent(freshSession(), "KICK_OFF", obs(T0, "sampler-kick"));
  assert.equal(started.session.engine, undefined);
  const frame = show(started.session, T0 + 30000);
  assert.equal(frame.frame.reason, "UNSAMPLED_GAP");
  assert.equal(frame.text, null);
  assert.equal(started.session.firstHalfClosedMs, frame.frame.session.firstHalfClosedMs);
});

test("a legacy running anchor migrates without rewriting the v1 record", () => {
  const store = slots();
  const prior = legacy();
  const started = applyIntent(freshSession(), "KICK_OFF", obs(T0, "legacy-kick"));
  const saved = commitSession(prior, started.session);
  assert.equal(saved.ok, true);
  const bytes = prior.box.file;
  const loaded = loadLiveClock(store, prior, EPOCH, T0 + 10 * 60000);
  assert.equal(loaded.reason, "MIGRATED_ANCHOR");
  assert.equal(loaded.session.engine, "utc_segment");
  assert.equal(show(loaded.session, T0 + 10 * 60000).text, "10:00");
  assert.equal(prior.box.file, bytes);
  assert.equal(prior.box.kv, bytes);
  const kept = commitSegment(store, loaded.session);
  assert.equal(kept.ok, true);
  assert.equal(prior.box.file, bytes);
  store.box.engine = "sampler";
  const rolled = loadLiveClock(store, prior, EPOCH, T0 + 10 * 60000);
  assert.equal(rolled.engine, "sampler");
  assert.equal(rolled.reason, "RECOVERY_REQUIRED");
  assert.equal(rolled.session.trust, Trust.UNVERIFIED);
});

test("a small epoch correction is absorbed and a jumped epoch fails closed", () => {
  const session = kick(T0);
  const small = show(session, T0 + 1000, "epoch-b");
  assert.equal(small.frame.admitted, true);
  assert.equal(small.frame.session.epoch, "epoch-b");
  assert.equal(small.text, "00:01");
  const jumped = show(session, T0 + 10 * 60000, "epoch-c");
  assert.equal(jumped.frame.reason, "EPOCH");
  assert.equal(jumped.frame.session.integrity, "TIME_UNKNOWN");
});
