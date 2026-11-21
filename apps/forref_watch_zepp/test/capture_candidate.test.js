import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  Admission,
  Evidence,
  FIXTURE,
  JOURNAL_FILE,
  assessCapture,
  bindRecoveredCandidate,
  createJournal,
  decideCaptureTap,
  intentForCaptureTap,
  memoryAdapter,
  parseJournal,
  stableStringify,
} from "../utils/capture_candidate.js";
import { isAbsentFileError, readCaptureJournal } from "../utils/capture_storage.js";

function journal(limits) {
  return createJournal(memoryAdapter(), limits);
}

function goal(extra) {
  return Object.assign({ eventToken: "GOAL", teamToken: "HOME", fixtureMode: true }, extra || {});
}

test("a fixture goal is a structured candidate without a display label or shirt number", () => {
  const draft = assessCapture(goal({ playerToken: "PLAYER 9" }));
  assert.equal(draft.admissionState, Admission.VALID_STRUCTURED_CANDIDATE);
  assert.equal(draft.matchId, FIXTURE.matchId);
  assert.equal(draft.canonicalCandidatePayload.matchTeamId, FIXTURE.homeTeamId);
  assert.equal(draft.canonicalCandidatePayload.player, undefined);
  assert.equal(draft.canonicalCandidatePayload.matchTeamId === "HOME", false);
  assert.equal(JSON.stringify(draft.canonicalCandidatePayload).includes("PLAYER"), false);
  assert.equal(draft.createdUtcDiagnosticOnly, null);
  assert.equal(draft.canonicalText.includes("matchTime"), false);
});

test("ordinary HOME and AWAY stay incomplete and are not team ids", () => {
  const home = assessCapture({ eventToken: "GOAL", teamToken: "HOME", fixtureMode: false, playerToken: "PLAYER 9" });
  const away = assessCapture({ eventToken: "GOAL", teamToken: "AWAY", fixtureMode: false });
  assert.equal(home.admissionState, Admission.INCOMPLETE_IDENTITY);
  assert.equal(home.matchId, null);
  assert.equal(home.canonicalCandidatePayload.matchTeamId, null);
  assert.equal(away.canonicalCandidatePayload.matchTeamId, null);
  assert.equal(stableStringify(home.canonicalCandidatePayload).includes("HOME"), false);
  assert.equal(stableStringify(away.canonicalCandidatePayload).includes("AWAY"), false);
});

test("yellow, red, substitution, and second caution are not promoted", () => {
  const yellow = assessCapture({ eventToken: "YELLOW", teamToken: "HOME", fixtureMode: true, playerToken: "PLAYER 9" });
  const red = assessCapture({ eventToken: "RED", teamToken: "HOME", fixtureMode: true });
  const sub = assessCapture({ eventToken: "SUB", teamToken: "HOME", fixtureMode: true });
  const second = assessCapture({ eventToken: "SECOND_CAUTION_SEND_OFF", teamToken: "HOME", fixtureMode: true });
  assert.equal(yellow.admissionState, Admission.INCOMPLETE_IDENTITY);
  assert.equal(yellow.canonicalCandidatePayload.participantId, null);
  assert.equal(red.kind, "RED_BUTTON");
  assert.equal(red.admissionState, Admission.UNSUPPORTED_SEMANTICS);
  assert.equal(red.canonicalCandidatePayload.sendOff, false);
  assert.equal(sub.admissionState, Admission.INCOMPLETE_IDENTITY);
  assert.equal(sub.canonicalCandidatePayload.outgoingParticipantId, null);
  assert.equal(second.admissionState, Admission.INCOMPLETE_IDENTITY);
  assert.deepEqual(second.canonicalCandidatePayload.dependencies, []);
});

test("append readback keeps id, sequence, and order across a new journal instance", () => {
  const adapter = memoryAdapter();
  const first = createJournal(adapter);
  const written = first.append(goal());
  assert.equal(written.ok, true);
  assert.equal(written.evidence, Evidence.READBACK_MATCHED);
  assert.equal(written.d1, Evidence.HARDWARE_D1_UNCERTIFIED);
  assert.equal(written.entry.localSequence, 1);
  assert.equal(written.entry.captureIntentId, written.entry.candidateId);
  const second = first.append(goal({ teamToken: "AWAY" }));
  assert.equal(second.entry.localSequence, 2);
  const reopened = createJournal(adapter);
  const recovered = reopened.read();
  assert.equal(recovered.ok, true);
  assert.equal(recovered.evidence, Evidence.RECREATION_RECOVERED);
  assert.deepEqual(
    recovered.entries.map((entry) => entry.captureIntentId),
    [written.entry.captureIntentId, second.entry.captureIntentId]
  );
  assert.deepEqual(
    recovered.entries.map((entry) => entry.localSequence),
    [1, 2]
  );
  assert.equal(recovered.entries[0].canonicalCandidatePayload.matchTeamId, FIXTURE.homeTeamId);
  assert.equal(recovered.entries[1].canonicalCandidatePayload.matchTeamId, FIXTURE.awayTeamId);
});

test("the same id and payload is idempotent and a different payload conflicts", () => {
  const book = journal();
  const intent = "SIM_INTENT_FIXED";
  const first = book.append(goal({ captureIntentId: intent }));
  const rawBefore = book.read();
  const again = book.append(goal({ captureIntentId: intent }));
  assert.equal(again.ok, true);
  assert.equal(again.duplicate, true);
  assert.equal(again.entry.captureIntentId, first.entry.captureIntentId);
  assert.equal(book.read().entries.length, 1);
  const conflict = book.append(goal({ captureIntentId: intent, teamToken: "AWAY" }));
  assert.equal(conflict.ok, false);
  assert.equal(conflict.admissionState, Admission.CONFLICT);
  assert.equal(book.read().entries.length, 1);
  assert.equal(stableStringify(book.read().entries[0].canonicalCandidatePayload), stableStringify(rawBefore.entries[0].canonicalCandidatePayload));
});

test("a short write and a thrown write are not acknowledged as valid", () => {
  const adapter = memoryAdapter();
  const book = createJournal(adapter);
  const kept = book.append(goal());
  assert.equal(kept.ok, true);
  adapter.store.mode = "short";
  const torn = book.append(goal({ teamToken: "AWAY", captureIntentId: "SIM_INTENT_TORN" }));
  assert.equal(torn.ok, false);
  assert.equal(torn.admissionState, Admission.UNVERIFIED_STORAGE);
  assert.equal(torn.reason, "SHORT_WRITE");
  assert.equal(torn.readablePrefix.length, 1);
  assert.equal(torn.readablePrefix[0].captureIntentId, kept.entry.captureIntentId);
  const blocked = book.append(goal({ teamToken: "AWAY", captureIntentId: "SIM_INTENT_AFTER" }));
  assert.equal(blocked.ok, false);
  assert.equal(blocked.admissionState, Admission.CORRUPT);
  assert.equal(adapter.store.raw.includes("SIM_INTENT_AFTER"), false);
  assert.equal(adapter.store.raw.includes(kept.entry.captureIntentId), true);

  const clean = memoryAdapter();
  const other = createJournal(clean);
  clean.store.mode = "throw";
  const failed = other.append(goal({ captureIntentId: "SIM_INTENT_DISK" }));
  assert.equal(failed.ok, false);
  assert.equal(failed.reason, "WRITE_EXCEPTION");
  assert.equal(clean.store.raw, "");
  clean.store.mode = "ok";
  const retried = other.append(goal({ captureIntentId: "SIM_INTENT_DISK" }));
  assert.equal(retried.ok, true);
  assert.equal(retried.entry.captureIntentId, "SIM_INTENT_DISK");
  assert.equal(other.read().entries.length, 1);
});

test("torn, corrupt, gapped, and unknown schema journals fail closed", () => {
  const adapter = memoryAdapter();
  const book = createJournal(adapter);
  book.append(goal());
  const intact = adapter.store.raw;
  adapter.store.raw = intact + "CB1|E|2|5|deadbeef|";
  const torn = parseJournal(adapter.store.raw);
  assert.equal(torn.ok, false);
  assert.equal(torn.reason, "TORN_TAIL");
  assert.equal(torn.readablePrefix.length, 1);
  adapter.store.raw = intact.replace("GOAL", "XXXX");
  const corrupt = parseJournal(adapter.store.raw);
  assert.equal(corrupt.ok, false);
  assert.equal(corrupt.quarantined, true);
  adapter.store.raw = intact;
  const parsed = parseJournal(intact);
  const gapLine = parsed.entries.length === 1 ? intact.replace("|1|", "|3|") : intact;
  const gap = parseJournal(gapLine);
  assert.equal(gap.ok, false);
  assert.equal(gap.reason, "SEQUENCE_GAP");
  const unknown = parseJournal(intact.replace('"schema":1', '"schema":2'));
  assert.equal(unknown.ok, false);
  assert.equal(unknown.reason, "UNSUPPORTED_SCHEMA");
  const blocked = createJournal(adapter);
  adapter.store.raw = intact + "CB1|E|2|5|deadbeef|";
  const before = adapter.store.raw;
  const refused = blocked.append(goal({ teamToken: "AWAY" }));
  assert.equal(refused.ok, false);
  assert.equal(adapter.store.raw, before);
});

test("capacity exhaustion preserves the earlier entries", () => {
  const book = journal({ maxEntries: 2 });
  assert.equal(book.append(goal({ captureIntentId: "SIM_INTENT_ONE" })).ok, true);
  assert.equal(book.append({ eventToken: "YELLOW", teamToken: "HOME", fixtureMode: false, captureIntentId: "SIM_INTENT_TWO" }).ok, true);
  const full = book.append(goal({ teamToken: "AWAY", captureIntentId: "SIM_INTENT_THREE" }));
  assert.equal(full.ok, false);
  assert.equal(full.reason, "CAPACITY");
  assert.deepEqual(
    book.read().entries.map((entry) => entry.captureIntentId),
    ["SIM_INTENT_ONE", "SIM_INTENT_TWO"]
  );
});

test("match ids stay isolated and two yellows do not create a send-off", () => {
  const book = journal();
  book.append(goal({ captureIntentId: "SIM_INTENT_GOAL" }));
  book.append({ eventToken: "YELLOW", teamToken: "HOME", fixtureMode: true, captureIntentId: "SIM_INTENT_Y1" });
  book.append({ eventToken: "YELLOW", teamToken: "AWAY", fixtureMode: false, captureIntentId: "SIM_INTENT_Y2" });
  const all = book.read();
  assert.equal(all.entries.filter((entry) => entry.matchId === FIXTURE.matchId).length, 2);
  assert.equal(all.entries.filter((entry) => entry.matchId === "SIM_MATCH_002").length, 0);
  assert.equal(all.entries.some((entry) => entry.kind.indexOf("SEND_OFF") >= 0), false);
  assert.equal(all.entries.filter((entry) => entry.kind === "YELLOW").length, 2);
});

test("the same player can have two yellows, while a retry keeps one id", () => {
  const book = journal();
  const yellow = { eventToken: "YELLOW", teamToken: "HOME", playerToken: "PLAYER 9", fixtureMode: false };
  const first = book.append(Object.assign({}, yellow, { captureIntentId: intentForCaptureTap("", false) }));
  assert.equal(first.ok, true);
  assert.equal(first.entry.kind, "YELLOW");
  const open = first.entry.captureIntentId;
  const retry = book.append(Object.assign({}, yellow, { captureIntentId: intentForCaptureTap(open, false) }));
  assert.equal(retry.duplicate, true);
  assert.equal(retry.entry.captureIntentId, open);
  assert.equal(book.read().entries.length, 1);
  const fresh = book.append(Object.assign({}, yellow, { captureIntentId: intentForCaptureTap(open, true) }));
  assert.equal(fresh.ok, true);
  assert.equal(fresh.duplicate, false);
  assert.notEqual(fresh.entry.captureIntentId, open);
  const entries = book.read().entries;
  assert.equal(entries.length, 2);
  assert.equal(entries[0].kind, "YELLOW");
  assert.equal(entries[1].kind, "YELLOW");
  assert.equal(stableStringify(entries[0].canonicalCandidatePayload), stableStringify(entries[1].canonicalCandidatePayload));
});

test("a missing journal is empty and an unknown stat or read failure does not append", () => {
  assert.equal(isAbsentFileError({ code: "ENOENT" }), true);
  assert.equal(isAbsentFileError(new Error("no such file")), true);
  assert.equal(isAbsentFileError(new Error("EIO: input/output error")), false);
  const absent = readCaptureJournal({
    stat() {
      throw new Error("ENOENT: no such file");
    },
    open() {
      throw new Error("opened");
    },
    read() {
      throw new Error("read");
    },
    close() {
      return 0;
    },
  });
  assert.equal(absent.status, "absent");
  assert.equal(absent.bytes, "");
  const nullStat = readCaptureJournal({
    stat() {
      return null;
    },
    open() {
      throw new Error("opened");
    },
    read() {
      throw new Error("read");
    },
    close() {
      return 0;
    },
  });
  assert.equal(nullStat.status, "absent");
  let opened = 0;
  assert.throws(() => {
    readCaptureJournal({
      stat() {
        throw new Error("EIO: input/output error");
      },
      open() {
        opened += 1;
        return 1;
      },
      read() {
        return { length: 0, text: "" };
      },
      close() {
        return 0;
      },
    });
  });
  assert.equal(opened, 0);
  let closed = 0;
  assert.throws(() => {
    readCaptureJournal({
      stat() {
        return { size: 4 };
      },
      open() {
        return 7;
      },
      read() {
        throw new Error("EIO read");
      },
      close() {
        closed += 1;
        return 0;
      },
    });
  });
  assert.equal(closed, 1);

  let statAppends = 0;
  const statAdapter = {
    readAll() {
      return readCaptureJournal({
        stat() {
          throw new Error("EIO: input/output error");
        },
        open() {
          throw new Error("open");
        },
        read() {
          return { length: 0, text: "" };
        },
        close() {
          return 0;
        },
      }).bytes;
    },
    append() {
      statAppends += 1;
      return 0;
    },
  };
  const statFailed = createJournal(statAdapter).append(goal());
  assert.equal(statFailed.ok, false);
  assert.equal(statFailed.reason, "READ_EXCEPTION");
  assert.equal(statFailed.admissionState, Admission.UNVERIFIED_STORAGE);
  assert.equal(statAppends, 0);

  let reads = 0;
  let appends = 0;
  const disk = { raw: "" };
  const adapter = {
    readAll() {
      reads += 1;
      if (reads === 2) {
        throw new Error("EIO during capacity");
      }
      return readCaptureJournal({
        stat() {
          return disk.raw.length === 0 ? null : { size: disk.raw.length };
        },
        open() {
          return 1;
        },
        read() {
          return { length: disk.raw.length, text: disk.raw };
        },
        close() {
          return 0;
        },
      }).bytes;
    },
    append(text) {
      appends += 1;
      disk.raw += text;
      return text.length;
    },
  };
  const failed = createJournal(adapter).append(goal({ captureIntentId: "SIM_INTENT_CAPACITY" }));
  assert.equal(failed.ok, false);
  assert.equal(failed.reason, "READ_EXCEPTION");
  assert.equal(failed.admissionState, Admission.UNVERIFIED_STORAGE);
  assert.equal(failed.attemptedId, "SIM_INTENT_CAPACITY");
  assert.equal(appends, 0);
  assert.equal(disk.raw, "");
});

test("a lost intent id after a verified append duplicates until reconcile refuses", () => {
  const yellow = { eventToken: "YELLOW", teamToken: "HOME", playerToken: "PLAYER 9", fixtureMode: false };
  const otherShirt = { eventToken: "YELLOW", teamToken: "AWAY", playerToken: "PLAYER 4", fixtureMode: false };
  const source = memoryAdapter();
  const firstBook = createJournal(source);
  const first = firstBook.append(Object.assign({}, yellow, { captureIntentId: "" }));
  assert.equal(first.ok, true);
  const bytesAfterFirst = source.store.raw;

  const naive = memoryAdapter();
  naive.store.raw = bytesAfterFirst;
  const duplicated = createJournal(naive).append(Object.assign({}, yellow, { captureIntentId: "" }));
  assert.equal(duplicated.ok, true);
  assert.equal(duplicated.entry.localSequence, 2);
  assert.notEqual(duplicated.entry.captureIntentId, first.entry.captureIntentId);

  const guarded = memoryAdapter();
  guarded.store.raw = bytesAfterFirst;
  const book = createJournal(guarded);
  const loaded = book.read();
  assert.equal(loaded.evidence, Evidence.RECREATION_RECOVERED);
  const refused = decideCaptureTap({ fresh: false, openIntentId: "", loaded: loaded, input: yellow });
  assert.equal(refused.action, "REFUSE");
  assert.equal(refused.reason, "RECONCILE_REQUIRED");
  assert.equal(guarded.store.raw, bytesAfterFirst);
  const shifted = decideCaptureTap({ fresh: false, openIntentId: "", loaded: loaded, input: otherShirt });
  assert.equal(shifted.action, "REFUSE");
  assert.equal(shifted.reason, "RECONCILE_REQUIRED");
  const inspected = bindRecoveredCandidate(loaded, first.entry.captureIntentId);
  assert.equal(inspected.ok, true);
  assert.equal(inspected.entry.captureIntentId, first.entry.captureIntentId);
  assert.equal(guarded.store.raw, bytesAfterFirst);
  const retryDecision = decideCaptureTap({
    fresh: false,
    openIntentId: inspected.captureIntentId,
    loaded: book.read(),
    input: yellow,
  });
  assert.equal(retryDecision.action, "APPEND");
  assert.equal(retryDecision.reason, "RETRY_OPEN");
  const retry = book.append(Object.assign({}, yellow, { captureIntentId: retryDecision.captureIntentId }));
  assert.equal(retry.duplicate, true);
  assert.equal(retry.entry.captureIntentId, first.entry.captureIntentId);
  assert.equal(book.read().entries.length, 1);
  const freshDecision = decideCaptureTap({
    fresh: true,
    openIntentId: inspected.captureIntentId,
    loaded: book.read(),
    input: yellow,
  });
  assert.equal(freshDecision.action, "APPEND");
  assert.equal(freshDecision.reason, "NEW_OCCURRENCE");
  assert.equal(freshDecision.captureIntentId, "");
  const second = book.append(Object.assign({}, yellow, { captureIntentId: freshDecision.captureIntentId }));
  assert.equal(second.ok, true);
  assert.equal(second.duplicate, false);
  assert.notEqual(second.entry.captureIntentId, first.entry.captureIntentId);
  assert.equal(book.read().entries.filter((entry) => entry.kind === "YELLOW").length, 2);
  assert.equal(book.read().entries.some((entry) => entry.kind.indexOf("SEND_OFF") >= 0), false);
});

test("changed context, a corrupt journal, and staged faults do not claim a new candidate", () => {
  const yellow = { eventToken: "YELLOW", teamToken: "HOME", playerToken: "PLAYER 9", fixtureMode: false };
  const book = journal();
  const first = book.append(Object.assign({}, yellow, { captureIntentId: "SIM_INTENT_Y1" }));
  assert.equal(first.ok, true);
  const before = book.read().entries[0].canonicalCandidatePayload;
  const conflict = book.append(goal({ captureIntentId: "SIM_INTENT_Y1" }));
  assert.equal(conflict.ok, false);
  assert.equal(conflict.admissionState, Admission.CONFLICT);
  assert.equal(stableStringify(book.read().entries[0].canonicalCandidatePayload), stableStringify(before));
  const stillOpen = decideCaptureTap({
    fresh: false,
    openIntentId: "SIM_INTENT_Y1",
    loaded: book.read(),
    input: goal(),
  });
  assert.equal(stillOpen.action, "APPEND");
  assert.equal(stillOpen.captureIntentId, "SIM_INTENT_Y1");

  const corruptAdapter = memoryAdapter();
  corruptAdapter.store.raw = "CB1|E|1|5|deadbeef|";
  const corruptBook = createJournal(corruptAdapter);
  const corrupt = corruptBook.read();
  assert.equal(corrupt.ok, false);
  const blocked = decideCaptureTap({ fresh: false, openIntentId: "", loaded: corrupt, input: yellow });
  assert.equal(blocked.action, "REFUSE");
  assert.notEqual(blocked.reason, "RECONCILE_REQUIRED");
  const bytes = corruptAdapter.store.raw;
  const refusedAppend = corruptBook.append(yellow);
  assert.equal(refusedAppend.ok, false);
  assert.equal(corruptAdapter.store.raw, bytes);
  assert.equal(bindRecoveredCandidate(corrupt, "SIM_INTENT_Y1").ok, false);

  let reads = 0;
  const disk = { raw: "" };
  const tornRead = {
    readAll() {
      reads += 1;
      if (reads >= 3) {
        throw new Error("EIO after append");
      }
      return disk.raw;
    },
    append(text) {
      disk.raw += text;
      return text.length;
    },
  };
  const uncertain = createJournal(tornRead).append(Object.assign({}, yellow, { captureIntentId: "SIM_INTENT_WINDOW" }));
  assert.equal(uncertain.ok, false);
  assert.equal(uncertain.reason, "READBACK_MISMATCH");
  assert.equal(uncertain.admissionState, Admission.UNVERIFIED_STORAGE);
  assert.equal(uncertain.attemptedId, "SIM_INTENT_WINDOW");
  assert.equal(disk.raw.includes("SIM_INTENT_WINDOW"), true);
  const recovered = createJournal({
    readAll() {
      return disk.raw;
    },
    append() {
      throw new Error("inspect must not append");
    },
  }).read();
  const silent = decideCaptureTap({ fresh: false, openIntentId: "", loaded: recovered, input: yellow });
  assert.equal(silent.action, "REFUSE");
  assert.equal(silent.reason, "RECONCILE_REQUIRED");
  const bound = bindRecoveredCandidate(recovered, uncertain.attemptedId);
  assert.equal(bound.ok, true);
  const replay = createJournal({
    readAll() {
      return disk.raw;
    },
    append() {
      throw new Error("retry must not append");
    },
  }).append(Object.assign({}, yellow, { captureIntentId: bound.captureIntentId }));
  assert.equal(replay.duplicate, true);
  assert.equal(replay.ok, true);
});

test("the committed envelope fixture matches a fresh append", () => {
  const adapter = memoryAdapter();
  const book = createJournal(adapter, { diagnosticDeviceSource: "10158337" });
  const result = book.append(goal({ playerToken: "PLAYER 9", captureIntentId: "SIM_INTENT_GOAL" }));
  const fixturePath = new URL("./fixtures/valid_goal_envelope.json", import.meta.url);
  const fixture = JSON.parse(readFileSync(fixturePath, "utf8"));
  assert.deepEqual(fixture, result.entry);
});

test("the watch surface stays on the review route and off the clock files", () => {
  const review = readFileSync(new URL("../page/gt/review/index.page.js", import.meta.url), "utf8");
  const text = readFileSync(new URL("../utils/text.js", import.meta.url), "utf8");
  const app = JSON.parse(readFileSync(new URL("../app.json", import.meta.url), "utf8"));
  const clock = readFileSync(new URL("../utils/clock_device.js", import.meta.url), "utf8");
  const paths = readFileSync(new URL("../utils/clock_store_paths.js", import.meta.url), "utf8");
  const session = readFileSync(new URL("../utils/live_session.js", import.meta.url), "utf8");
  const device = readFileSync(new URL("../utils/capture_device.js", import.meta.url), "utf8");
  assert.equal(app.targets.gt.module.page.pages.length, 25);
  assert.equal(review.includes("watchCaptureAdapter"), true);
  assert.equal(review.includes("SAVED"), false);
  assert.equal(review.includes("OFFICIAL"), false);
  assert.equal(review.includes("matchTime"), false);
  assert.equal(review.includes("clock_device"), false);
  assert.equal(review.includes("live_session"), false);
  assert.equal(paths.includes("forref_clock001c_state"), true);
  assert.equal(clock.includes("CLOCK_FILE"), true);
  assert.equal(clock.includes("capture_candidate"), false);
  assert.equal(session.includes("capture_candidate"), false);
  assert.equal(device.includes("openSync"), true);
  assert.equal(device.includes("writeSync"), true);
  assert.equal(device.includes("readSync"), true);
  assert.equal(device.includes("closeSync"), true);
  assert.equal(device.includes("readCaptureJournal"), true);
  const readFn = device.slice(device.indexOf("readAll"), device.indexOf("append(text)"));
  assert.equal(readFn.includes("return \"\""), false);
  assert.equal(device.includes("JOURNAL_FILE"), true);
  assert.equal(JOURNAL_FILE, "forref_capture_bridge_001.journal");
  assert.equal(device.includes("forref_clock"), false);
  assert.equal(review.includes("review-new"), true);
  assert.equal(review.includes("decideCaptureTap"), true);
  assert.equal(review.includes("bindRecoveredCandidate"), true);
  assert.equal(review.includes("decision.action !== \"APPEND\""), true);
  for (const key of ["captureTest", "newCapture", "viewLocal", "simFixtureOff", "localCandidate", "notMatchRecord", "candidateRecovered", "candidateIncomplete", "captureFailed", "reconcileRequired", "boundCandidate"]) {
    assert.equal(text.split(key + ":").length - 1 >= 2, true, key);
  }
});
