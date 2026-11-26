import { back } from "@zos/router";
import { readFileSync, writeFileSync } from "@zos/fs";
import { logDevice, bindBack, clear, stack } from "../../../utils/chrome";
import { t, showTeam, showEvent, showPlayer } from "../../../utils/text";
import { state } from "../../../utils/state";
import { GOAL_JOURNAL_FILE, createFileGoalStore, createGoalJournal } from "../../../utils/goal_journal";
import { readGoalContext } from "../../../utils/local_test_score";
import { Admission, Evidence, bindRecoveredCandidate, createJournal, decideCaptureTap } from "../../../utils/capture_candidate";
import { watchCaptureAdapter, watchDiagnosticSource } from "../../../utils/capture_device";
import { TEXT_WARNING } from "../../../utils/theme";

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
  if (s.captureNote === "reconcile") {
    return t("reconcileRequired");
  }
  if (s.captureNote === "bound" && s.captureIndex) {
    return t("boundCandidate") + " #" + s.captureIndex + " — " + t("notMatchRecord");
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
    { label: statusLine(s, loaded), color: TEXT_WARNING },
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
  rows.push({ label: loaded.entries.length === 0 && loaded.ok ? t("candidateNone") : statusLine(s, loaded), color: TEXT_WARNING });
  const shown = loaded.ok ? loaded.entries.slice(0, 3) : [];
  for (let i = 0; i < shown.length; i++) {
    const entry = shown[i];
    const mark = entry.admissionState === Admission.VALID_STRUCTURED_CANDIDATE ? t("localCandidate") : t("candidateIncomplete");
    rows.push({
      label: "#" + entry.localSequence + " " + mark + " " + entry.captureIntentId,
      action: () => {
        const bound = bindRecoveredCandidate(loaded, entry.captureIntentId);
        if (!bound.ok) {
          s.captureNote = "failed";
          s.captureView = false;
          paint();
          return;
        }
        s.captureIntentId = bound.captureIntentId;
        s.captureIndex = bound.entry.localSequence;
        s.captureNote = "bound";
        s.captureView = false;
        console.log(
          "FORREF_CAPTURE reconcile=bind seq=" +
            bound.entry.localSequence +
            " id=" +
            bound.captureIntentId +
            " d1=UNCERTIFIED"
        );
        paint();
      },
      name: "review-bind-" + entry.localSequence,
    });
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

function captureInput(s) {
  return {
    eventToken: s.event,
    teamToken: s.team,
    playerToken: s.player,
    fixtureMode: s.captureFixture === true,
  };
}

function capture(s, fresh) {
  const input = captureInput(s);
  const loaded = journal().read();
  const decision = decideCaptureTap({
    fresh: fresh,
    openIntentId: s.captureIntentId,
    loaded: loaded,
    input: input,
  });
  console.log(
    "FORREF_CAPTURE decide=" +
      decision.action +
      " reason=" +
      decision.reason +
      " id=" +
      (decision.captureIntentId || "")
  );
  if (decision.action !== "APPEND") {
    s.captureNote = decision.reason === "RECONCILE_REQUIRED" ? "reconcile" : "failed";
    console.log(
      "FORREF_CAPTURE seq= id= admission=" +
        (loaded.admissionState || "") +
        " evidence=" +
        (loaded.evidence || "") +
        " reason=" +
        decision.reason +
        " duplicate=0 d1=UNCERTIFIED"
    );
    paint();
    return;
  }
  const result = journal().append({
    eventToken: input.eventToken,
    teamToken: input.teamToken,
    playerToken: input.playerToken,
    fixtureMode: input.fixtureMode,
    captureIntentId: decision.captureIntentId,
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

function paintGoal(m, s) {
  if (!s.goalIntentId) {
    s.goalIntentId = "goal-" + Date.now().toString(36) + "-" + Math.floor(Math.random() * 1000000).toString(36);
    s.goalRecordId = "rec-" + s.goalIntentId;
  }
  stack(m, t("confirmGoal"), [
    { label: showTeam(s.team) + " · " + t("goal") },
    { label: s.goalNote || t("localTest"), color: TEXT_WARNING },
    {
      label: t("confirmGoal"),
      action: () => confirmGoal(s),
      name: "review-goal-confirm",
    },
    { label: t("back"), action: () => back(), name: "review-back" },
  ]);
}

function confirmGoal(s) {
  const fs = { readFileSync: readFileSync, writeFileSync: writeFileSync };
  const context = readGoalContext(fs);
  const teamId = !context ? "" : s.team === "HOME" ? context.homeTeamId : s.team === "AWAY" ? context.awayTeamId : "";
  if (!context || !teamId) {
    s.goalNote = t("recoveryRequired");
    console.log("FORREF_EVENT outcome=REFUSED reason=provision");
    paint();
    return;
  }
  const result = createGoalJournal(
    createFileGoalStore(fs, GOAL_JOURNAL_FILE),
    Object.assign({ localInstallationId: context.writerDeviceId }, context),
  ).append({
    captureIntentId: s.goalIntentId,
    recordId: s.goalRecordId,
    scoringTeamId: teamId,
  });
  console.log("FORREF_SCORE outcome=" + result.outcome + " reason=" + (result.reason || ""));
  if (result.uncertain) {
    s.goalNote = t("recoveryRequired");
    paint();
    return;
  }
  if (!result.ok) {
    s.goalNote = t("captureFailed");
    paint();
    return;
  }
  s.goalIntentId = "";
  s.goalRecordId = "";
  s.goalNote = "";
  back();
}

function paint() {
  const m = logDevice("review");
  clear();
  const s = state();
  if (s.event === "GOAL") {
    console.log("FORREF_CONTEXT team=" + s.team + " event=GOAL player=");
    paintGoal(m, s);
    return;
  }
  const loaded = journal().read();
  console.log("FORREF_CONTEXT team=" + s.team + " event=" + s.event + " player=" + s.player);
  if (s.captureView) {
    paintView(m, s, loaded);
    return;
  }
  paintForm(m, s, loaded);
}

Page({
  onInit() {
    console.log("FORREF_LIFE review onInit event=" + state().event);
  },
  build() {
    bindBack(false);
    paint();
  },
  onDestroy() {
    console.log("FORREF_LIFE review onDestroy");
  },
});
