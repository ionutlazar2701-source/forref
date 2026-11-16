import { back } from "@zos/router";
import { logDevice, bindBack, clear, stack } from "../../../utils/chrome";
import { t, showTeam, showEvent, showPlayer } from "../../../utils/text";
import { state } from "../../../utils/state";
import { Admission, Evidence, createJournal, intentForCaptureTap } from "../../../utils/capture_candidate";
import { watchCaptureAdapter, watchDiagnosticSource } from "../../../utils/capture_device";

function journal() {
  return createJournal(watchCaptureAdapter(), {
    diagnosticDeviceSource: watchDiagnosticSource(),
  });
}

function selectionKey(s) {
  return (s.captureFixture ? "SIM" : "RAW") + "|" + (s.team || "") + "|" + (s.event || "") + "|" + (s.player || "");
}

function logCapture(result) {
  const entry = result.entry || {};
  console.log(
    "FORREF_CAPTURE seq=" +
      (entry.localSequence == null ? "" : entry.localSequence) +
      " id=" +
      (entry.captureIntentId || "") +
      " admission=" +
      (result.admissionState || "") +
      " evidence=" +
      (result.evidence || "") +
      " reason=" +
      (result.reason || "") +
      " duplicate=" +
      (result.duplicate ? 1 : 0) +
      " d1=UNCERTIFIED"
  );
}

function statusLine(s, loaded) {
  if (s.captureNote === "failed") {
    return t("captureFailed");
  }
  if (s.captureNote === "conflict") {
    return t("candidateConflict");
  }
  if (s.captureNote === "incomplete") {
    return t("candidateIncomplete");
  }
  if (s.captureNote === "readback" && s.captureIndex) {
    return t("localCandidate") + " #" + s.captureIndex + " — " + t("notMatchRecord");
  }
  if (!loaded.ok) {
    return t("captureFailed");
  }
  if (loaded.entries.length > 0) {
    return t("candidateRecovered");
  }
  return t("notRecorded");
}

function paintForm(m, s, loaded) {
  const key = selectionKey(s);
  if (s.captureIntentKey !== key) {
    s.captureIntentKey = key;
    s.captureIntentId = "";
    s.captureNote = "";
    s.captureIndex = 0;
  }
  if (!loaded.ok && !s.captureQuarantineLogged) {
    s.captureQuarantineLogged = true;
    const prefix = loaded.readablePrefix || [];
    console.log(
      "FORREF_CAPTURE quarantine=1 reason=" +
        (loaded.reason || "") +
        " prefix=" +
        prefix.map((entry) => entry.captureIntentId).join(",") +
        " d1=UNCERTIFIED"
    );
  }
  if (loaded.entries.length > 0 && !s.captureRecoveryLogged && !s.captureNote) {
    s.captureRecoveryLogged = true;
    console.log(
      "FORREF_CAPTURE evidence=" +
        Evidence.RECREATION_RECOVERED +
        " count=" +
        loaded.entries.length +
        " id=" +
        loaded.entries.map((entry) => entry.captureIntentId).join(",") +
        " d1=UNCERTIFIED"
    );
  }
  stack(m, t("review"), [
    { label: showTeam(s.team) + " · " + showEvent(s.event) + " · " + showPlayer(s.player) },
    { label: statusLine(s, loaded), color: 0xc4a35a },
    {
      label: s.captureFixture ? t("simFixtureOn") : t("simFixtureOff"),
      action: () => {
        s.captureFixture = !s.captureFixture;
        s.captureIntentId = "";
        s.captureNote = "";
        console.log("FORREF_CAPTURE fixture=" + (s.captureFixture ? "SIM" : "OFF"));
        paint();
      },
      name: "review-fixture",
    },
    {
      label: t("captureTest"),
      action: () => capture(s, false),
      name: "review-capture",
    },
    {
      label: t("newCapture"),
      action: () => capture(s, true),
      name: "review-new",
    },
    {
      label: t("viewLocal"),
      action: () => {
        s.captureView = true;
        paint();
      },
      name: "review-view",
    },
    { label: t("back"), action: () => back(), name: "review-back" },
  ]);
}

function paintView(m, s, loaded) {
  const rows = [];
  rows.push({ label: loaded.entries.length === 0 && loaded.ok ? t("candidateNone") : statusLine(s, loaded), color: 0xc4a35a });
  const shown = loaded.ok ? loaded.entries.slice(0, 3) : [];
  for (let i = 0; i < shown.length; i++) {
    const entry = shown[i];
    const mark = entry.admissionState === Admission.VALID_STRUCTURED_CANDIDATE ? t("localCandidate") : t("candidateIncomplete");
    rows.push({ label: "#" + entry.localSequence + " " + mark + " " + entry.captureIntentId });
  }
  while (rows.length < 4) {
    rows.push({ label: " " });
  }
  rows.push({
    label: t("reviewCapture"),
    action: () => {
      s.captureView = false;
      paint();
    },
    name: "review-return",
  });
  rows.push({ label: t("back"), action: () => back(), name: "review-back" });
  stack(m, t("viewLocal"), rows);
}

function capture(s, fresh) {
  const result = journal().append({
    eventToken: s.event,
    teamToken: s.team,
    playerToken: s.player,
    fixtureMode: s.captureFixture === true,
    captureIntentId: intentForCaptureTap(s.captureIntentId, fresh),
  });
  logCapture(result);
  if (result.entry && result.entry.captureIntentId) {
    s.captureIntentId = result.entry.captureIntentId;
    s.captureIndex = result.entry.localSequence;
  } else if (result.attemptedId) {
    s.captureIntentId = result.attemptedId;
  }
  if (result.ok && result.entry) {
    s.captureNote = result.entry.admissionState === Admission.VALID_STRUCTURED_CANDIDATE ? "readback" : "incomplete";
  } else if (result.admissionState === Admission.CONFLICT) {
    s.captureNote = "conflict";
  } else {
    s.captureNote = "failed";
  }
  paint();
}

function paint() {
  const m = logDevice("review");
  clear();
  const s = state();
  const loaded = journal().read();
  console.log("FORREF_CONTEXT team=" + s.team + " event=" + s.event + " player=" + s.player);
  if (s.captureView) {
    paintView(m, s, loaded);
    return;
  }
  paintForm(m, s, loaded);
}

Page({
  build() {
    bindBack(false);
    paint();
  },
});
