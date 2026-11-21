import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  ERROR_LIMIT_MS,
  PROVEN,
  UNKNOWN,
  admitSource,
  parseSportDuration,
  readSportDuration,
  reviewHardware,
  timingMatrix,
} from "../lib/native_elapsed.js";

function physical(errorMs) {
  return {
    measured: true,
    device: "Amazfit Bip 6",
    source: "PHYSICAL_BIP6",
    javascriptTicksUsed: false,
    repeatedWakes: true,
    reopen: true,
    bluetoothDrop: true,
    pauseResume: true,
    intervals: [
      { sleepSeconds: 30, absErrorMs: errorMs },
      { sleepSeconds: 120, absErrorMs: errorMs },
      { sleepSeconds: 600, absErrorMs: errorMs },
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

test("a successful sport callback is still time unknown", () => {
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

test("the hardware gate stays shut without a complete physical report", () => {
  assert.equal(reviewHardware(null).reason, "NO_PHYSICAL_REPORT");
  const ticks = physical(0);
  ticks.javascriptTicksUsed = true;
  assert.equal(reviewHardware(ticks).reason, "JAVASCRIPT_TICKS");
  const incomplete = physical(0);
  incomplete.pauseResume = false;
  assert.equal(reviewHardware(incomplete).reason, "PROTOCOL_INCOMPLETE");
  const short = physical(0);
  short.intervals = short.intervals.filter((row) => row.sleepSeconds !== 600);
  assert.equal(reviewHardware(short).reason, "INTERVAL_MISSING");
  assert.equal(reviewHardware(physical(ERROR_LIMIT_MS + 1)).reason, "ERROR_OVER_LIMIT");
  const accepted = reviewHardware(physical(ERROR_LIMIT_MS));
  assert.equal(accepted.status, PROVEN);
  assert.equal(accepted.proven, true);
  assert.equal(accepted.worstAbsErrorMs, 1000);
});

test("the lab and the match app do not call the sport reader", () => {
  const lab = readFileSync(new URL("../app.json", import.meta.url), "utf8");
  const production = readFileSync(new URL("../../forref_watch_zepp/app.json", import.meta.url), "utf8");
  const probe = readFileSync(new URL("../lib/native_elapsed.js", import.meta.url), "utf8");
  assert.equal(lab.includes("data:user.hd.workout"), false);
  assert.equal(lab.includes("getSportData"), false);
  assert.equal(production.includes("data:user.hd.workout"), false);
  assert.equal(probe.includes("@zos"), false);
  assert.equal(JSON.parse(production).targets.gt.module.page.pages.length, 23);
  const bip = timingMatrix().find((row) => row.capability === "workout_extension_on_bip6");
  assert.equal(bip.availability, "UNAVAILABLE");
  const standalone = timingMatrix().find((row) => row.capability === "standalone_bip6_native_elapsed_after_sleep");
  assert.equal(standalone.availability, "NO_SUPPORTED_PATH");
  assert.equal(standalone.state, "HARDWARE_PENDING");
});
