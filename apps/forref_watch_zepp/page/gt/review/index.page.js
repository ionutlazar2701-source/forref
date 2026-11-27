import { back } from "@zos/router";
import { O_APPEND, O_CREAT, O_WRONLY, closeSync, openSync, readFileSync, writeFileSync, writeSync } from "@zos/fs";
import { logDevice, bindBack, clear, stack } from "../../../utils/chrome";
import { t, showTeam, showEvent, showPlayer } from "../../../utils/text";
import { state } from "../../../utils/state";
import { commitGoalCapture, openLocalGoal, resumeGoalCapture } from "../../../utils/goal_capture";
import { localTestScore, publishLocalScore } from "../../../utils/local_test_score";
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

function goalFs() {
  return {
    readFileSync: readFileSync,
    writeFileSync: writeFileSync,
    openSync: openSync,
    writeSync: writeSync,
    closeSync: closeSync,
    O_WRONLY: O_WRONLY,
    O_CREAT: O_CREAT,
    O_APPEND: O_APPEND,
  };
}

function prepareGoal(s) {
  if (s.goalCapturePrepared) return;
  s.goalCapturePrepared = true;
  const opened = openLocalGoal(goalFs(), "");
  s.goalMatchId = opened.admitted.matchId || "";
  s.goalHomeTeamId = opened.admitted.homeTeamId || "";
  s.goalAwayTeamId = opened.admitted.awayTeamId || "";
  if (!opened.admitted.localCandidate || !opened.ok || !opened.journal || !opened.pendingStore) {
    s.goalDecision = "RECOVERY_REQUIRED";
    s.goalNote = t("recoveryRequired");
    console.log("FORREF_RECOVERY outcome=RECOVERY_REQUIRED reason=" + (opened.reason || opened.admitted.reason || "provision"));
    return;
  }
  const selected = s.team === "HOME" ? opened.admitted.homeTeamId : s.team === "AWAY" ? opened.admitted.awayTeamId : "";
  const decision = resumeGoalCapture({
    pendingStore: opened.pendingStore,
    journal: opened.journal,
    ui: s,
    matchId: opened.admitted.matchId,
    scoringTeamId: selected,
    userAction: s.goalUserAction === true,
  });
  s.goalUserAction = false;
  s.goalDecision = decision.action;
  s.goalScoringTeamId = decision.scoringTeamId || "";
  if (decision.action === "RECOVERY_REQUIRED" || decision.action === "UNCERTAIN" || decision.action === "IDLE") {
    s.goalNote = t("recoveryRequired");
    return;
  }
  s.goalNote = t("localTest");
}

function paintGoal(m, s) {
  prepareGoal(s);
  const credited = s.goalScoringTeamId && s.goalScoringTeamId === s.goalHomeTeamId
    ? t("home")
    : s.goalScoringTeamId && s.goalScoringTeamId === s.goalAwayTeamId
      ? t("away")
      : showTeam(s.team);
  const rows = [
    { label: credited + " · " + t("goal") },
    { label: s.goalNote || t("localTest"), color: TEXT_WARNING },
  ];
  if (s.goalDecision === "READY" || s.goalDecision === "RETRY" || s.goalDecision === "ALREADY_RECORDED") {
    rows.push({
      label: t("confirmGoal"),
      action: () => confirmGoal(s),
      name: "review-goal-confirm",
    });
  }
  rows.push({ label: t("back"), action: () => back(), name: "review-back" });
  stack(m, t("confirmGoal"), rows);
}

function confirmGoal(s) {
  const opened = openLocalGoal(goalFs(), s.goalMatchId || "");
  if (!opened.admitted.localCandidate || !opened.ok || !opened.journal || !opened.pendingStore) {
    s.goalNote = t("recoveryRequired");
    s.goalDecision = "RECOVERY_REQUIRED";
    console.log("FORREF_EVENT outcome=REFUSED reason=" + (opened.reason || opened.admitted.reason || "provision"));
    paint();
    return;
  }
  const result = commitGoalCapture({
    pendingStore: opened.pendingStore,
    journal: opened.journal,
    ui: s,
    matchId: opened.admitted.matchId,
    scoringTeamId: s.goalScoringTeamId,
    userAction: false,
  });
  console.log("FORREF_SCORE outcome=" + result.outcome + " reason=" + (result.reason || ""));
  if (result.uncertain || !result.ok) {
    s.goalNote = t("recoveryRequired");
    s.goalDecision = result.uncertain ? "RECOVERY_REQUIRED" : "REFUSED";
    paint();
    return;
  }
  const loaded = opened.journal.load();
  publishLocalScore(localTestScore(loaded.entries, opened.admitted, loaded.status));
  s.goalUserAction = false;
  s.goalCapturePrepared = false;
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
