import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  LOCAL_BRIDGE_URL,
  acceptPhoneMessage,
  applyFetch,
  createLocalBridge,
  teamLabel,
} from "../utils/local_bridge.js";

function phonePayload(home, away, matchId) {
  return {
    payloadVersion: 1,
    matchId: matchId,
    updatedAt: "2026-11-21T11:00:00.000Z",
    date: "2026-11-21",
    competition: null,
    venue: null,
    homeTeamId: "home",
    homeTeamName: home,
    awayTeamId: "away",
    awayTeamName: away,
    halfDurationSeconds: 2700,
    extraTimeEnabled: false,
    extraTimeHalfDurationSeconds: 0,
    referee: null,
    assistantReferee1: null,
    assistantReferee2: null,
    fourthOfficial: null,
  };
}

function memoryIo(initial) {
  let text = initial || "";
  return {
    write(value) {
      text = value;
    },
    read() {
      return text;
    },
    snapshot() {
      return text;
    },
  };
}

function fetchPayload(payload, status) {
  return async (url) => {
    assert.equal(url, LOCAL_BRIDGE_URL);
    return {
      status: status || 200,
      text: async () => JSON.stringify(payload),
    };
  };
}

test("the side service returns the phone payload and no static names", async () => {
  const bridge = createLocalBridge();
  const answer = await bridge.answer(
    { method: "GET_LOCAL_CONFIGURATION", params: {} },
    fetchPayload(phonePayload("River", "Delta", "match-river"))
  );
  assert.equal(answer.error, null);
  assert.equal(answer.data.disposition, "payload");
  assert.equal(answer.data.payload.homeTeamName, "River");
  assert.equal(answer.data.payload.awayTeamName, "Delta");
  assert.equal(answer.data.payload.matchId, "match-river");
  assert.equal(Object.hasOwn(answer.data.payload, "score"), false);
  assert.equal(JSON.stringify(answer.data).includes("North"), false);
  assert.equal(JSON.stringify(answer.data).includes("South"), false);
  const accepted = acceptPhoneMessage(answer.data);
  assert.equal(accepted.ok, true);
  const receipt = await bridge.answer(
    {
      method: "LOCAL_CONFIGURATION_STORED",
      params: {
        payloadVersion: 1,
        matchId: "match-river",
        contentHash: accepted.record.contentHash,
      },
    },
    async () => {
      throw new Error("receipt must not fetch");
    }
  );
  assert.equal(receipt.data.disposition, "recorded");
});

test("a failed fetch does not invent names or replace a saved phone payload", async () => {
  const bridge = createLocalBridge();
  const first = await bridge.answer(
    { method: "GET_LOCAL_CONFIGURATION", params: {} },
    fetchPayload(phonePayload("River", "Delta", "match-river"))
  );
  const io = memoryIo();
  const stored = applyFetch(first.data, io);
  assert.equal(stored.stored, true);
  assert.equal(stored.names.home, "River");

  const offline = await bridge.answer(
    { method: "GET_LOCAL_CONFIGURATION", params: {} },
    async () => {
      throw new Error("connection refused");
    }
  );
  assert.equal(offline.data.disposition, "unavailable");
  assert.equal(Object.hasOwn(offline.data, "homeTeamName"), false);
  const kept = applyFetch(offline.data, io);
  assert.equal(kept.stored, false);
  assert.equal(kept.savedCopy, true);
  assert.equal(kept.names.home, "River");
  assert.equal(kept.names.away, "Delta");
  assert.equal(io.snapshot().includes("River"), true);

  const missing = await bridge.answer(
    { method: "GET_LOCAL_CONFIGURATION", params: {} },
    fetchPayload({ disposition: "missing" }, 404)
  );
  assert.equal(missing.data.disposition, "unavailable");
  const still = applyFetch(missing.data, io);
  assert.equal(still.names.home, "River");
});

test("an edited phone payload replaces the saved names", async () => {
  const bridge = createLocalBridge();
  const io = memoryIo();
  const first = await bridge.answer(
    { method: "GET_LOCAL_CONFIGURATION", params: {} },
    fetchPayload(phonePayload("River", "Delta", "match-river"))
  );
  applyFetch(first.data, io);
  const second = await bridge.answer(
    { method: "GET_LOCAL_CONFIGURATION", params: {} },
    fetchPayload(phonePayload("Oak", "Elm", "match-river"))
  );
  const edited = applyFetch(second.data, io);
  assert.equal(edited.stored, true);
  assert.equal(edited.names.home, "Oak");
  assert.equal(edited.names.away, "Elm");
  assert.equal(io.snapshot().includes("River"), false);
});

test("the static fixture, a sporting body, and a hash mismatch are refused", async () => {
  const bridge = createLocalBridge();
  const empty = memoryIo();
  const fixture = await bridge.answer(
    { method: "GET_LOCAL_CONFIGURATION", params: {} },
    fetchPayload({
      payloadVersion: 1,
      probe: "A",
      matchId: "probe-a-static",
      homeTeamName: "North",
      awayTeamName: "South",
      source: "side-service-static",
    })
  );
  assert.equal(fixture.data.disposition, "unavailable");
  const refused = applyFetch(fixture.data, empty);
  assert.equal(refused.names, null);
  assert.equal(empty.snapshot(), "");

  const sporting = phonePayload("River", "Delta", "match-river");
  sporting.score = { home: 1, away: 0 };
  const blocked = await bridge.answer(
    { method: "GET_LOCAL_CONFIGURATION", params: {} },
    fetchPayload(sporting)
  );
  assert.equal(blocked.data.disposition, "unavailable");

  const good = await bridge.answer(
    { method: "GET_LOCAL_CONFIGURATION", params: {} },
    fetchPayload(phonePayload("Harbor", "Field", "match-ui"))
  );
  const tampered = Object.assign({}, good.data, { contentHash: "00000000" });
  assert.equal(acceptPhoneMessage(tampered).reason, "hash");
  assert.equal(teamLabel(null, "NAME NOT SET"), "NAME NOT SET");
  assert.equal(teamLabel("Harbor", "NAME NOT SET"), "Harbor");
});

test("the local bridge module does not embed a team-name fallback", () => {
  const source = readFileSync(new URL("../utils/local_bridge.js", import.meta.url), "utf8");
  const page = readFileSync(new URL("../page/gt/local/index.page.js", import.meta.url), "utf8");
  assert.equal(source.includes("North"), false);
  assert.equal(source.includes("South"), false);
  assert.equal(page.includes("North"), false);
  assert.equal(page.includes("South"), false);
  assert.equal(page.includes("paintBase("), true);
  assert.equal(source.includes(LOCAL_BRIDGE_URL), true);
});
