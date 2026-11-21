import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  BIP6_SOURCES,
  ERROR_LIMIT_MS,
  PROBE_ID,
  PROBE_VERSION,
  PROVEN,
  UNKNOWN,
  WORKOUT_PERMISSION,
  admitSource,
  applyPermissionCallback,
  applyPermissionQuery,
  applyPermissionRequest,
  applySportResult,
  beginPending,
  initialProbe,
  markStillPending,
  openSportRead,
  parseSportDuration,
  readSportDuration,
  reviewHardware,
  timingMatrix,
} from "../lib/native_elapsed.js";

function raw(total) {
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const seconds = total % 60;
  const mm = minutes < 10 ? "0" + minutes : String(minutes);
  const ss = seconds < 10 ? "0" + seconds : String(seconds);
  return JSON.stringify([{ duration: hours + ":" + mm + ":" + ss, name: "Duration" }]);
}

function reading(kind, sleepSeconds, durationSeconds, stopwatchSeconds) {
  return {
    kind: kind,
    sleepSeconds: sleepSeconds,
    api: "getSportData",
    type: "duration",
    permission: 2,
    accepted: true,
    code: 0,
    raw: raw(durationSeconds),
    stopwatchSeconds: stopwatchSeconds,
  };
}

function physical(stopwatchOffset) {
  return {
    deviceSource: BIP6_SOURCES[0],
    probe: PROBE_ID,
    version: PROBE_VERSION,
    reads: [
      reading("sleep", 30, 30, 30 + stopwatchOffset),
      reading("sleep", 120, 120, 120 + stopwatchOffset),
      reading("sleep", 600, 600, 600 + stopwatchOffset),
      reading("wake", 0, 40, 40),
      reading("wake", 0, 80, 80),
      reading("wake", 0, 100, 100),
      reading("reopen", 0, 130, 130),
      reading("bluetooth", 0, 140, 140),
      reading("pause", 0, 150, 150),
      reading("resume", 0, 150, 180),
    ],
  };
}

test("a documented duration string translates and stays unproven", () => {
  const founder = parseSportDuration("1:05:34");
  assert.equal(founder.ok, true);
  assert.equal(founder.seconds, 3934);
  assert.equal(founder.referee, "65:34");
  assert.equal(founder.proven, false);
  const sample = parseSportDuration("1:15:15");
  assert.equal(sample.seconds, 4515);
  assert.equal(sample.referee, "75:15");
  assert.equal(parseSportDuration("0:00:00").referee, "0:00");
  assert.equal(parseSportDuration("10:00:01").referee, "600:01");
});

test("shapes the docs do not show are rejected", () => {
  for (const text of ["65:34", "1:5:34", "1:15", "1:15:60", "1:60:00", "", null, 4515]) {
    const parsed = parseSportDuration(text);
    assert.equal(parsed.ok, false, String(text));
    assert.equal(parsed.seconds, null);
    assert.equal(parsed.proven, false);
  }
});

test("a synchronous sport callback stays time unknown and a late callback stays pending", () => {
  const reading = readSportDuration(function (options, callback) {
    assert.equal(options.type, "duration");
    callback({ code: 0, data: JSON.stringify([{ duration: "1:05:34", name: "Duration" }]) });
    return true;
  });
  assert.equal(reading.status, UNKNOWN);
  assert.equal(reading.proven, false);
  assert.equal(reading.referee, "65:34");
  assert.equal(reading.reason, "DISPLAY_STRING_NOT_ELAPSED");
  assert.equal(readSportDuration(null).reason, "NO_READER");
  assert.equal(readSportDuration(function () { return false; }).reason, "CALL_REJECTED");
  assert.equal(readSportDuration(function () { throw new Error("denied"); }).reason, "READER_THREW");
  assert.equal(readSportDuration(function (options, callback) {
    callback({ code: 1, data: "" });
    return true;
  }).reason, "SPORT_CODE");
  assert.equal(readSportDuration(function (options, callback) {
    callback({ code: 0, data: "not-json" });
    return true;
  }).reason, "UNDOCUMENTED_SHAPE");
  let delivered = null;
  let late = null;
  const opened = openSportRead(function (options, callback) {
    late = callback;
    return true;
  }, function (result) { delivered = result; });
  assert.equal(opened.phase, "PENDING");
  assert.equal(delivered, null);
  late({ code: 0, data: raw(65) });
  assert.equal(delivered.reason, "DISPLAY_STRING_NOT_ELAPSED");
  assert.equal(delivered.referee, "1:05");
  assert.equal(delivered.proven, false);
  late({ code: 0, data: raw(99) });
  assert.equal(delivered.referee, "1:05");
  assert.equal(readSportDuration(function () { return true; }).reason, "CALLBACK_PENDING");
});

test("permission results keep the documented numeric codes", () => {
  let state = applyPermissionQuery(initialProbe(), [2]);
  assert.equal(state.permission, 2);
  assert.equal(state.permissionReason, "AUTHORIZED");
  state = applyPermissionQuery(state, [0]);
  assert.equal(state.permissionReason, "NOT_AUTHORIZED");
  state = applyPermissionQuery(state, [1]);
  assert.equal(state.permissionReason, "UNKNOWN_PERMISSION");
  assert.equal(applyPermissionQuery(state, true).permissionReason, "PERMISSION_SHAPE");
  state = applyPermissionRequest(state, 0);
  assert.equal(state.requestImmediate, 0);
  state = applyPermissionCallback(state, [2]);
  assert.equal(state.requestList, 2);
  assert.equal(state.permission, 2);
  assert.equal(applyPermissionRequest(state, "yes").permissionReason, "REQUEST_SHAPE");
});

test("a pending read is not turned into an API error before the callback", () => {
  let late = null;
  const opened = openSportRead(function (options, callback) {
    late = callback;
    return true;
  }, function (result) { late = result; });
  assert.equal(opened.phase, "PENDING");
  let state = beginPending(initialProbe(), true);
  assert.equal(state.reason, "CALLBACK_PENDING");
  state = markStillPending(state);
  assert.equal(state.reason, "NO_CALLBACK_10S");
  assert.equal(state.status, UNKNOWN);
  state = applySportResult(state, {
    status: UNKNOWN,
    reason: "SPORT_CODE",
    accepted: true,
    code: 5,
    raw: "",
    durationText: "",
    referee: "",
  });
  assert.equal(state.phase, "SETTLED");
  assert.equal(state.code, 5);
  assert.equal(state.reason, "SPORT_CODE");
  assert.equal(markStillPending(state).reason, "SPORT_CODE");
});

test("none of the documented clocks are proven elapsed time", () => {
  for (const kind of [
    "SPORT_DISPLAY_STRING",
    "WORKOUT_HISTORY_SECONDS",
    "SYS_TIMER_CALLBACK",
    "UTC_WALL_CLOCK",
    "SYSTEM_APP_JUMP",
    "OTHER",
  ]) {
    const admitted = admitSource(kind);
    assert.equal(admitted.status, UNKNOWN, kind);
    assert.equal(admitted.proven, false, kind);
  }
  assert.equal(admitSource("SYS_TIMER_CALLBACK").reason, "CALLBACK_NOT_DURATION");
  assert.equal(admitSource("UTC_WALL_CLOCK").reason, "WALL_CLOCK_NOT_ELAPSED");
  assert.equal(admitSource("SYSTEM_APP_JUMP").reason, "LAUNCH_NOT_A_READING");
});

test("asserted success flags and invalid API evidence do not pass", () => {
  assert.equal(reviewHardware(null).reason, "NO_PHYSICAL_REPORT");
  const asserted = physical(0);
  asserted.measured = true;
  assert.equal(reviewHardware(asserted).reason, "ASSERTED_FIELD");
  const ticks = physical(0);
  ticks.reads[0].absErrorMs = 0;
  assert.equal(reviewHardware(ticks).reason, "ASSERTED_FIELD");
  const flags = physical(0);
  flags.pauseResume = true;
  assert.equal(reviewHardware(flags).reason, "ASSERTED_FIELD");
  const denied = physical(0);
  denied.reads[0].permission = 0;
  assert.equal(reviewHardware(denied).reason, "PERMISSION");
  const unknownPerm = physical(0);
  unknownPerm.reads[2].permission = true;
  assert.equal(reviewHardware(unknownPerm).reason, "PERMISSION");
  const unsupported = physical(0);
  unsupported.reads[1].code = 5;
  assert.equal(reviewHardware(unsupported).reason, "SPORT_CODE");
  assert.equal(reviewHardware(unsupported).callbackCode, 5);
  const wrongApi = physical(0);
  wrongApi.reads[0].api = "createSysTimer";
  assert.equal(reviewHardware(wrongApi).reason, "API_IDENTITY");
  const badRaw = physical(0);
  badRaw.reads[2].raw = JSON.stringify([{ duration: "10:00", name: "Duration" }]);
  assert.equal(reviewHardware(badRaw).reason, "UNDOCUMENTED_SHAPE");
  const negative = physical(0);
  negative.reads[0].stopwatchSeconds = -1;
  assert.equal(reviewHardware(negative).reason, "STOPWATCH");
  const over = reviewHardware(physical(1.001));
  assert.equal(over.reason, "ERROR_OVER_LIMIT");
  assert.equal(over.worstAbsErrorMs > ERROR_LIMIT_MS, true);
  const short = physical(0);
  short.reads = short.reads.filter((row) => row.sleepSeconds !== 600);
  assert.equal(reviewHardware(short).reason, "INTERVAL_MISSING");
  const noWake = physical(0);
  noWake.reads = noWake.reads.filter((row) => row.kind !== "wake");
  assert.equal(reviewHardware(noWake).reason, "WAKE_MISSING");
  const wrongWatch = physical(0);
  wrongWatch.deviceSource = 1;
  assert.equal(reviewHardware(wrongWatch).reason, "DEVICE_SOURCE");
});

test("a complete payload within one second can pass the gate", () => {
  const accepted = reviewHardware(physical(1));
  assert.equal(accepted.status, PROVEN);
  assert.equal(accepted.proven, true);
  assert.equal(accepted.worstAbsErrorMs, 1000);
  assert.equal(reviewHardware(physical(0)).worstAbsErrorMs, 0);
});

test("the match app and the sensor lab do not call the sport reader", () => {
  const lab = readFileSync(new URL("../app.json", import.meta.url), "utf8");
  const production = readFileSync(new URL("../../forref_watch_zepp/app.json", import.meta.url), "utf8");
  const probeModule = readFileSync(new URL("../lib/native_elapsed.js", import.meta.url), "utf8");
  const probeApp = readFileSync(new URL("../../forref_duration_probe/app.json", import.meta.url), "utf8");
  const probePage = readFileSync(new URL("../../forref_duration_probe/page/gt/home/index.page.js", import.meta.url), "utf8");
  assert.equal(lab.includes(WORKOUT_PERMISSION), false);
  assert.equal(lab.includes("getSportData"), false);
  assert.equal(production.includes(WORKOUT_PERMISSION), false);
  assert.equal(probeModule.includes("@zos"), false);
  assert.equal(JSON.parse(production).targets.gt.module.page.pages.length, 23);
  assert.equal(JSON.parse(probeApp).permissions.indexOf(WORKOUT_PERMISSION) >= 0, true);
  assert.equal(JSON.parse(probeApp).app.appId === 29566, false);
  assert.equal(JSON.parse(probeApp).app.appId === 30101, false);
  assert.equal(probePage.includes("getSportData"), true);
  assert.equal(probePage.includes("queryPermission"), true);
  assert.equal(probePage.includes("requestPermission"), true);
  assert.equal(probePage.includes("openSportRead"), true);
  assert.equal(probePage.includes("createSysTimer"), false);
  assert.equal(probePage.includes("PROVEN_TIME"), false);
  const standalone = timingMatrix().find((row) => row.capability === "standalone_bip6_getSportData_duration");
  assert.equal(standalone.state, "HARDWARE_NOT_TESTED");
});
