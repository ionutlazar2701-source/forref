import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  AVAILABILITY,
  capabilityMatrix,
  characterizeDistanceReading,
  compareKnownRoute,
  extensionListed,
  parseSportCallback,
  SPORT_ABSENT_TYPES,
} from "../lib/native_sport.js";

test("API level does not put the Bip 6 on the Workout Extension list", () => {
  assert.equal(extensionListed("Amazfit T-Rex 3"), true);
  assert.equal(extensionListed("Amazfit Bip 6"), false);
  const row = capabilityMatrix().find((item) => item.metric === "workout_extension_on_bip6");
  assert.equal(row.availability, "UNAVAILABLE");
});

test("sport callbacks stay uncertified and absent types are not invented", () => {
  const distance = parseSportCallback("distance", { code: 0, data: JSON.stringify([{ distance: "9.99", name: "Distance" }]) });
  assert.equal(distance.ok, true);
  assert.equal(distance.availability, "EXTENSION_ONLY");
  assert.equal(distance.unit, "UNRESOLVED");
  assert.equal(distance.certified, false);
  const speed = parseSportCallback("speed", { code: 0, data: JSON.stringify([{ speed: "1.40", name: "Speed" }]) });
  assert.equal(speed.valueText, "1.40");
  const duration = parseSportCallback("duration", { code: 0, data: JSON.stringify([{ duration: "1:15:15", name: "Duration" }]) });
  assert.equal(duration.valueText, "1:15:15");
  assert.equal(parseSportCallback("distance", { code: 1, data: "" }).reason, "NO_SAMPLE");
  assert.equal(parseSportCallback("max_speed", { code: 0, data: "{\"max_speed\":\"12\"}" }).availability, "UNAVAILABLE");
  assert.equal(parseSportCallback("track", { code: 0, data: "[]" }).reason, "TYPE_NOT_DOCUMENTED");
  assert.ok(SPORT_ABSENT_TYPES.indexOf("latitude") >= 0);
});

test("the distance sensor is an unresolved aggregate, not a workout distance", () => {
  const reading = characterizeDistanceReading(1234);
  assert.equal(reading.availability, "AGGREGATE_ONLY");
  assert.equal(reading.unit, "UNRESOLVED");
  assert.equal(reading.sessionAttribution, "UNRESOLVED");
  assert.equal(reading.nativeWorkoutDistance, false);
  assert.equal(reading.usedInGnss, false);
  assert.equal(characterizeDistanceReading(null).value, null);
  const route = compareKnownRoute();
  assert.equal(route.availability, "HARDWARE_PENDING");
  assert.equal(route.compared, false);
  assert.equal(route.nativeMeters, null);
});

test("the matrix uses only the allowed labels and this build does not request workout access", () => {
  const rows = capabilityMatrix();
  for (let i = 0; i < rows.length; i++) {
    assert.equal(AVAILABILITY.indexOf(rows[i].availability) >= 0, true, rows[i].metric);
  }
  const lab = readFileSync(new URL("../app.json", import.meta.url), "utf8");
  const production = readFileSync(new URL("../../forref_watch_zepp/app.json", import.meta.url), "utf8");
  const home = readFileSync(new URL("../page/gt/home/index.page.js", import.meta.url), "utf8");
  assert.equal(lab.includes("data:user.hd.workout"), false);
  assert.equal(lab.includes("getSportData"), false);
  assert.equal(home.includes("getSportData"), false);
  assert.equal(production.includes("data:user.hd.workout"), false);
  assert.equal(JSON.parse(production).targets.gt.module.page.pages.length, 23);
});
