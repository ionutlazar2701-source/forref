import test from "node:test";
import assert from "node:assert/strict";
import {
  Phase,
  Trust,
  REGULATION_HALF_MS,
  freshSession,
  applyIntent,
  sample,
  present,
  displayText,
  loadSession,
  commitSession,
  advance,
  encodeSession,
  admitDisplay,
  liveFrame,
  DISPLAY_CONTINUITY_MS,
} from "../utils/match_clock.js";

const EPOCH = "epoch-a";

function obs(utc, id, extra) {
  return Object.assign({ utcMillis: utc, epoch: EPOCH, intentId: id }, extra || {});
}

function kick(at) {
  const started = applyIntent(freshSession(), "KICK_OFF", obs(at, "kick"));
  assert.equal(started.ok, true);
  return started.session;
}

function memory(seed) {
  const box = { file: seed == null ? "" : seed, kv: seed == null ? "" : seed };
  return {
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
    box: box,
  };
}

test("ready stays 00:00 and a second kickoff does not start another clock", () => {
  const ready = present(freshSession(), 0);
  assert.equal(ready.phase, Phase.READY);
  assert.equal(displayText(ready), "00:00");
  const session = kick(1000);
  assert.equal(session.phase, Phase.FIRST_HALF_RUNNING);
  const again = applyIntent(session, "KICK_OFF", obs(4000, "kick-2"));
  assert.equal(again.ok, false);
  assert.equal(again.session.phase, Phase.FIRST_HALF_RUNNING);
  assert.equal(again.session.firstHalfClosedMs, 0);
  assert.equal(again.session.openStartUtc, 1000);
  const same = applyIntent(session, "KICK_OFF", obs(4000, "kick"));
  assert.equal(same.duplicate, true);
  assert.equal(same.session.seq, session.seq);
});

test("elapsed follows the injected clock rather than the number of callbacks", () => {
  const session = kick(0);
  const once = sample(session, obs(5000, "tick"));
  assert.equal(once.event, "TICK");
  assert.equal(displayText(present(once.session, 5000)), "00:05");
  const skipped = sample(session, obs(20000, "tick"));
  assert.equal(displayText(present(skipped.session, 20000)), "00:20");
});

test("pause freezes and resume continues from the frozen value", () => {
  let session = advance(kick(0), 10000);
  const paused = applyIntent(session, "PAUSE", obs(10000, "pause"));
  assert.equal(paused.ok, true);
  session = paused.session;
  assert.equal(displayText(present(session, 40000)), "00:10");
  assert.equal(sample(session, obs(40000)).event, "HELD");
  const duplicate = applyIntent(session, "PAUSE", obs(11000, "pause"));
  assert.equal(duplicate.duplicate, true);
  const extra = applyIntent(session, "PAUSE", obs(11000, "pause-2"));
  assert.equal(extra.reason, "ILLEGAL");
  const resumed = applyIntent(session, "RESUME", obs(40000, "resume"));
  assert.equal(resumed.ok, true);
  session = advance(resumed.session, 44000);
  assert.equal(displayText(present(session, 44000)), "00:14");
  const resumeAgain = applyIntent(session, "RESUME", obs(44000, "resume"));
  assert.equal(resumeAgain.duplicate, true);
});

test("half-time is an explicit whistle before or after 45:00 and the break does not play", () => {
  const early = applyIntent(advance(kick(0), 12000), "END_FIRST_HALF", obs(12000, "half"));
  assert.equal(early.ok, true);
  assert.equal(early.session.phase, Phase.HALF_TIME);
  assert.equal(displayText(present(early.session, 90000)), "00:12");
  const long = kick(0);
  const atAdded = advance(long, 47 * 60 * 1000 + 15000);
  const ended = applyIntent(atAdded, "END_FIRST_HALF", obs(47 * 60 * 1000 + 15000, "half-long"));
  assert.equal(ended.session.phase, Phase.HALF_TIME);
  assert.equal(displayText(present(ended.session, 80 * 60 * 1000)), "45 + 02:15");
  assert.equal(ended.session.firstHalfClosedMs, 47 * 60 * 1000 + 15000);
});

test("second half starts once at 45:00 and keeps the real first-half elapsed", () => {
  const ended = applyIntent(advance(kick(0), 47 * 60 * 1000 + 15000), "END_FIRST_HALF", obs(47 * 60 * 1000 + 15000, "half"));
  const started = applyIntent(ended.session, "START_SECOND_HALF", obs(50 * 60 * 1000, "second"));
  assert.equal(started.ok, true);
  assert.equal(displayText(present(started.session, 50 * 60 * 1000)), "45:00");
  assert.equal(started.session.firstHalfClosedMs, 47 * 60 * 1000 + 15000);
  assert.equal(started.session.secondHalfClosedMs, 0);
  const again = applyIntent(started.session, "START_SECOND_HALF", obs(50 * 60 * 1000 + 1000, "second-2"));
  assert.equal(again.reason, "ILLEGAL");
  assert.equal(again.session.phase, Phase.SECOND_HALF_RUNNING);
});

test("full time is explicit at 89:00 or 90+ and never a completed match", () => {
  function toSecond(ms) {
    const ended = applyIntent(advance(kick(0), 1000), "END_FIRST_HALF", obs(1000, "half-" + ms));
    return applyIntent(ended.session, "START_SECOND_HALF", obs(2000, "second-" + ms)).session;
  }
  const at89 = advance(toSecond(89), 2000 + 44 * 60 * 1000);
  assert.equal(at89.phase, Phase.SECOND_HALF_RUNNING);
  assert.equal(displayText(present(at89, 2000 + 44 * 60 * 1000)), "89:00");
  const full89 = applyIntent(at89, "FULL_TIME", obs(2000 + 44 * 60 * 1000, "full-89"));
  assert.equal(full89.session.phase, Phase.FULL_TIME);
  assert.notEqual(full89.session.phase, "COMPLETED");
  assert.equal(displayText(present(full89.session, 999999)), "89:00");

  const added = 45 * 60 * 1000 + 3 * 60 * 1000 + 24000;
  const atAdded = advance(toSecond(added), 2000 + added);
  assert.equal(atAdded.phase, Phase.SECOND_HALF_RUNNING);
  assert.equal(displayText(present(atAdded, 2000 + added)), "90 + 03:24");
  const full = applyIntent(atAdded, "FULL_TIME", obs(2000 + added, "full-added"));
  assert.equal(full.session.phase, Phase.FULL_TIME);
  assert.equal(displayText(present(full.session, 2000 + added + 60000)), "90 + 03:24");
  assert.deepEqual(present(full.session, 0).actions, []);
});

test("illegal transitions and a reloaded running clock do not create a second kickoff", () => {
  const running = kick(0);
  assert.equal(applyIntent(running, "START_SECOND_HALF", obs(1000, "bad-2")).reason, "ILLEGAL");
  assert.equal(applyIntent(running, "FULL_TIME", obs(1000, "bad-ft")).reason, "ILLEGAL");
  const half = applyIntent(running, "END_FIRST_HALF", obs(1000, "half")).session;
  assert.equal(applyIntent(half, "RESUME", obs(2000, "bad-resume")).reason, "ILLEGAL");
  const store = memory();
  assert.equal(commitSession(store, running).ok, true);
  const loaded = loadSession(store, "epoch-b");
  assert.equal(loaded.reason, "RECOVERY_REQUIRED");
  assert.equal(loaded.session.trust, Trust.UNVERIFIED);
  assert.equal(displayText(present(loaded.session, 50000)), null);
  assert.equal(applyIntent(loaded.session, "KICK_OFF", obs(50000, "another")).reason, "UNVERIFIED");
});

test("regulation boundaries stay exact to the second and do not end the period", () => {
  const first = kick(0);
  assert.equal(displayText(present(advance(first, 44 * 60 * 1000 + 59000), 44 * 60 * 1000 + 59000)), "44:59");
  assert.equal(displayText(present(advance(first, REGULATION_HALF_MS), REGULATION_HALF_MS)), "45:00");
  const past = advance(first, REGULATION_HALF_MS + 1000);
  assert.equal(past.phase, Phase.FIRST_HALF_RUNNING);
  assert.equal(displayText(present(past, REGULATION_HALF_MS + 1000)), "45 + 00:01");

  const ended = applyIntent(kick(0), "END_FIRST_HALF", obs(1000, "half-boundary")).session;
  const second = applyIntent(ended, "START_SECOND_HALF", obs(2000, "second-boundary")).session;
  const base = 2000;
  assert.equal(displayText(present(advance(second, base + 44 * 60 * 1000 + 59000), base + 44 * 60 * 1000 + 59000)), "89:59");
  assert.equal(displayText(present(advance(second, base + REGULATION_HALF_MS), base + REGULATION_HALF_MS)), "90:00");
  const pastMatch = advance(second, base + REGULATION_HALF_MS + 1000);
  assert.equal(pastMatch.phase, Phase.SECOND_HALF_RUNNING);
  assert.equal(displayText(present(pastMatch, base + REGULATION_HALF_MS + 1000)), "90 + 00:01");
});

test("clock jumps, timezone, sleep, and bad recovery suppress exact digits", () => {
  const running = advance(kick(0), 10000);
  const back = sample(running, obs(9000));
  assert.equal(back.session.trust, Trust.UNVERIFIED);
  assert.equal(displayText(present(back.session, 9000)), null);
  const forward = sample(running, obs(10 * 60 * 1000));
  assert.equal(forward.session.notice, "FORWARD_GAP");
  assert.equal(forward.session.firstHalfClosedMs, 10000);
  const zone = sample(running, obs(11000, "z", { discontinuity: "TIMEZONE" }));
  assert.equal(zone.session.notice, "TIMEZONE");
  const sleep = sample(running, obs(11000, "s", { discontinuity: "SLEEP" }));
  assert.equal(sleep.session.notice, "SLEEP");

  const store = memory();
  assert.equal(commitSession(store, running).reason, "READBACK_ONLY_NOT_D1");
  store.box.file = "";
  store.box.kv = "";
  const gone = loadSession(store, EPOCH);
  assert.equal(gone.reason, "NO_PRIOR_PROOF");
  assert.equal(gone.session.phase, Phase.READY);
  assert.equal(encodeSession(running).includes("SAVED"), false);

  store.box.file = "{";
  store.box.kv = "{";
  assert.equal(loadSession(store, EPOCH).reason, "CORRUPT");
  store.box.file = encodeSession(running);
  store.box.kv = encodeSession(kick(5));
  const conflict = loadSession(store, EPOCH);
  assert.equal(conflict.reason, "CONFLICT");
  assert.equal(displayText(present(conflict.session, 0)), null);
});

test("storage failure and a partial write fail closed", () => {
  const session = kick(0);
  const broken = {
    writeFile() {
      throw new Error("disk");
    },
    readFile() {
      return "";
    },
    writeKv() {
      throw new Error("kv");
    },
    readKv() {
      return "";
    },
  };
  assert.equal(commitSession(broken, session).ok, false);
  const partial = memory();
  partial.writeKv = () => {
    throw new Error("kv");
  };
  assert.equal(commitSession(partial, session).ok, false);
  assert.notEqual(partial.box.file, partial.box.kv);
  assert.equal(loadSession(partial, EPOCH).reason, "CONFLICT");
  const liar = memory();
  liar.readFile = () => "other";
  assert.equal(commitSession(liar, session).reason, "READBACK");
  const down = {
    writeFile() {
      return true;
    },
    readFile() {
      throw new Error("io");
    },
    writeKv() {
      return true;
    },
    readKv() {
      throw new Error("io");
    },
  };
  assert.equal(loadSession(down, EPOCH).reason, "STORE_UNAVAILABLE");
  assert.deepEqual(present(loadSession(down, EPOCH).session, 0).actions, []);
});

test("a new continuity epoch restores a frozen pause and does not invent running time", () => {
  const paused = applyIntent(advance(kick(0), 15000), "PAUSE", obs(15000, "pause")).session;
  const store = memory();
  assert.equal(commitSession(store, paused).ok, true);
  const restored = loadSession(store, "epoch-after-recreate");
  assert.equal(restored.reason, "RESTORED_FROZEN");
  assert.equal(restored.session.phase, Phase.FIRST_HALF_PAUSED);
  assert.equal(displayText(present(restored.session, 999999)), "00:15");
  assert.equal(restored.session.openStartUtc, null);
  const running = kick(0);
  const liveStore = memory();
  commitSession(liveStore, advance(running, 20000));
  const recovered = loadSession(liveStore, "other-device");
  assert.equal(recovered.session.trust, Trust.UNVERIFIED);
  assert.equal(recovered.session.firstHalfClosedMs, 20000);
  assert.equal(displayText(present(recovered.session, 80000)), null);
  const continued = applyIntent(recovered.session, "CONTINUE_FROM_LAST", obs(80000, "continue", { epoch: "other-device" }));
  assert.equal(continued.ok, true);
  assert.equal(continued.session.phase, Phase.FIRST_HALF_PAUSED);
  assert.equal(displayText(present(continued.session, 80000)), "00:20");
});

test("reaching 45:00 or 90:00 does not emit a period or match end", () => {
  const first = advance(kick(0), REGULATION_HALF_MS);
  assert.equal(first.phase, Phase.FIRST_HALF_RUNNING);
  const ended = applyIntent(kick(0), "END_FIRST_HALF", obs(1000, "half-threshold")).session;
  const second = applyIntent(ended, "START_SECOND_HALF", obs(2000, "second-threshold")).session;
  const fullMark = advance(second, 2000 + REGULATION_HALF_MS);
  assert.equal(fullMark.phase, Phase.SECOND_HALF_RUNNING);
  assert.equal(displayText(present(fullMark, 2000 + REGULATION_HALF_MS)), "90:00");
});

test("formal suspension excludes the stopped interval and is not a clock pause", () => {
  let session = advance(kick(0), 10000);
  const suspended = applyIntent(session, "SUSPEND_GAME", obs(10000, "suspend"));
  assert.equal(suspended.ok, true);
  session = suspended.session;
  assert.equal(session.phase, Phase.FIRST_HALF_SUSPENDED);
  assert.equal(session.trust, Trust.FROZEN);
  assert.equal(displayText(present(session, 40000)), "00:10");
  assert.equal(session.firstHalfClosedMs, 10000);
  const pause = applyIntent(session, "PAUSE", obs(40000, "pause-while-suspended"));
  assert.equal(pause.ok, false);
  assert.equal(pause.session.phase, Phase.FIRST_HALF_SUSPENDED);
  const resumed = applyIntent(session, "RESUME_GAME", obs(40000, "resume-game"));
  assert.equal(resumed.ok, true);
  assert.equal(resumed.session.phase, Phase.FIRST_HALF_RUNNING);
  const later = advance(resumed.session, 45000);
  assert.equal(displayText(present(later, 45000)), "00:15");
});

test("suspend from paused does not open a second playing segment", () => {
  const paused = applyIntent(advance(kick(0), 12000), "PAUSE", obs(12000, "pause")).session;
  const suspended = applyIntent(paused, "SUSPEND_GAME", obs(20000, "suspend-paused"));
  assert.equal(suspended.ok, true);
  assert.equal(suspended.session.phase, Phase.FIRST_HALF_SUSPENDED);
  assert.equal(suspended.session.firstHalfClosedMs, 12000);
  assert.equal(suspended.session.openStartUtc, null);
  assert.equal(suspended.session.journal.filter((entry) => entry.intent === "SUSPEND_GAME").length, 1);
});

test("abandon is refused until confirmed and never becomes full time", () => {
  const running = advance(kick(0), 8000);
  const direct = applyIntent(running, "ABANDON_GAME", obs(8000, "abandon-direct", { confirmed: true }));
  assert.equal(direct.ok, false);
  assert.equal(direct.session.phase, Phase.FIRST_HALF_RUNNING);
  const suspended = applyIntent(running, "SUSPEND_GAME", obs(8000, "suspend-abandon")).session;
  const first = applyIntent(suspended, "ABANDON_GAME", obs(9000, "abandon-1"));
  assert.equal(first.reason, "CONFIRM_REQUIRED");
  assert.equal(first.session.phase, Phase.FIRST_HALF_SUSPENDED);
  const abandoned = applyIntent(suspended, "ABANDON_GAME", obs(9000, "abandon-2", { confirmed: true }));
  assert.equal(abandoned.ok, true);
  assert.equal(abandoned.session.phase, Phase.ABANDONED);
  assert.notEqual(abandoned.session.phase, Phase.FULL_TIME);
  assert.equal(displayText(present(abandoned.session, 20000)), "00:08");
  const kickAgain = applyIntent(abandoned.session, "KICK_OFF", obs(21000, "kick-after-abandon"));
  assert.equal(kickAgain.ok, false);
});

test("second-half suspension restores as frozen and resume stays in the second half", () => {
  const ended = applyIntent(advance(kick(0), 47000), "END_FIRST_HALF", obs(47000, "half")).session;
  const second = applyIntent(ended, "START_SECOND_HALF", obs(80000, "second")).session;
  const played = advance(second, 86000);
  const suspended = applyIntent(played, "SUSPEND_GAME", obs(86000, "suspend-2")).session;
  assert.equal(suspended.phase, Phase.SECOND_HALF_SUSPENDED);
  assert.equal(displayText(present(suspended, 120000)), "45:06");
  const store = memory();
  assert.equal(commitSession(store, suspended).ok, true);
  const restored = loadSession(store, "epoch-after-recreate");
  assert.equal(restored.reason, "RESTORED_FROZEN");
  assert.equal(restored.session.phase, Phase.SECOND_HALF_SUSPENDED);
  assert.equal(displayText(present(restored.session, 200000)), "45:06");
  const resumed = applyIntent(restored.session, "RESUME_GAME", obs(200000, "resume-2", { epoch: "epoch-after-recreate" }));
  assert.equal(resumed.session.phase, Phase.SECOND_HALF_RUNNING);
  assert.equal(displayText(present(advance(resumed.session, 203000), 203000)), "45:09");
});

test("an unsampled gap is not shown as precise elapsed time", () => {
  const session = advance(kick(0), 5000);
  assert.equal(session.lastUtc, 5000);
  assert.equal(displayText(present(session, 5000 + 30000)), "00:05");
  const gap = 5000 + DISPLAY_CONTINUITY_MS + 1;
  const denied = admitDisplay(session, gap, EPOCH);
  assert.equal(denied.admitted, false);
  assert.equal(denied.reason, "UNSAMPLED_GAP");
  assert.equal(denied.session.trust, Trust.UNVERIFIED);
  assert.equal(denied.session.firstHalfClosedMs, 5000);
  assert.equal(displayText(present(denied.session, gap)), null);
  const frame = liveFrame(session, gap, EPOCH);
  assert.equal(frame.admitted, false);
  assert.equal(frame.view.unverified, true);
  assert.equal(frame.view.digits, null);
  const continued = admitDisplay(session, 5000 + 1000, EPOCH);
  assert.equal(continued.admitted, true);
  assert.equal(continued.reason, "TICK");
  assert.equal(displayText(present(continued.session, 6000)), "00:06");
});

test("a late whistle does not fold the unsampled gap into the elapsed", () => {
  const session = advance(kick(0), 10000);
  const late = applyIntent(session, "PAUSE", obs(10000 + DISPLAY_CONTINUITY_MS + 50, "late-pause"));
  assert.equal(late.ok, false);
  assert.equal(late.reason, "UNSAMPLED_GAP");
  assert.equal(late.session.trust, Trust.UNVERIFIED);
  assert.equal(late.session.firstHalfClosedMs, 10000);
  assert.equal(displayText(present(late.session, 40000)), null);
  assert.equal(late.session.phase, Phase.FIRST_HALF_RUNNING);
});
