import { admitStoredGoal } from "./goal_admission.js";
import {
  createFileGoalStore,
  createGoalJournal,
  goalJournalName,
  readStoredText,
  selectGoalJournalPath,
} from "./goal_journal.js";

export const PENDING_SCHEMA = "forref.watch-goal-pending.v1";

export function pendingName(matchId) {
  if (!goalJournalName(matchId)) return "";
  return "forref_watch_goal_pending_v1." + matchId + ".json";
}

export function canonicalPending(pending) {
  return '{"schema":"' + PENDING_SCHEMA + '",' +
    '"matchId":' + JSON.stringify(pending.matchId) + "," +
    '"scoringTeamId":' + JSON.stringify(pending.scoringTeamId) + "," +
    '"captureIntentId":' + JSON.stringify(pending.captureIntentId) + "," +
    '"recordId":' + JSON.stringify(pending.recordId) + "}";
}

export function readPending(store) {
  const read = store.read();
  if (read.status === "unreadable") return { status: "unreadable", reason: "unreadable" };
  if (read.status === "absent" || !read.text) return { status: "absent" };
  let pending;
  try {
    pending = JSON.parse(read.text);
  } catch (err) {
    return { status: "corrupt", reason: "pending-corrupt" };
  }
  if (!pending || canonicalPending(pending) !== String(read.text).trim()) {
    return { status: "corrupt", reason: "pending-corrupt" };
  }
  return { status: "ok", pending: pending };
}

export function establishPending(store, pending) {
  const body = canonicalPending(pending);
  const wrote = store.write(body);
  const back = readPending(store);
  if (!wrote || wrote.status !== "ok" || !back.pending || back.pending.captureIntentId !== pending.captureIntentId) {
    console.log("FORREF_RECOVERY outcome=UNCERTAIN reason=pending-readback");
    return { ok: false, reason: "pending-readback" };
  }
  return { ok: true, pending: back.pending };
}

export function clearPending(store) {
  const wrote = store.write("");
  const back = store.read();
  if (wrote && (back.status === "absent" || back.text == null || back.text === "")) return { ok: true };
  console.log("FORREF_RECOVERY outcome=UNCERTAIN reason=pending-clear");
  return { ok: false, reason: "pending-clear" };
}

export function createMemoryPendingStore() {
  return {
    raw: null,
    failWrite: false,
    read() {
      if (this.raw == null || this.raw === "") return { status: "absent", text: "" };
      return { status: "ok", text: this.raw };
    },
    write(text) {
      if (this.failWrite) return { status: "unreadable" };
      this.raw = text;
      return { status: "ok", text: text };
    },
  };
}

export function createFilePendingStore(fs, path) {
  return {
    read() {
      return readStoredText(fs, path);
    },
    write(text) {
      try {
        fs.writeFileSync({ path: path, data: text, options: { encoding: "utf8" } });
      } catch (err) {
        return { status: "unreadable" };
      }
      const back = readStoredText(fs, path);
      if (text === "") {
        if (back.status === "absent" || back.text === "") return { status: "ok", text: "" };
        return { status: "unreadable", text: back.text || "" };
      }
      if (back.status !== "ok" || back.text !== text) return { status: "unreadable", text: back.text || "" };
      return { status: "ok", text: text };
    },
  };
}

export function allocateGoalIdentity() {
  const captureIntentId = "goal-" + Date.now().toString(36) + "-" + Math.floor(Math.random() * 1000000).toString(36);
  return { captureIntentId: captureIntentId, recordId: "rec-" + captureIntentId };
}

function bind(ui, pending) {
  ui.goalIntentId = pending.captureIntentId;
  ui.goalRecordId = pending.recordId;
  ui.goalScoringTeamId = pending.scoringTeamId;
}

export function resumeGoalCapture(options) {
  const ui = options.ui || {};
  const pendingRead = readPending(options.pendingStore);
  const loaded = options.journal.load();
  if (pendingRead.status === "unreadable" || pendingRead.status === "corrupt") {
    console.log("FORREF_RECOVERY outcome=RECOVERY_REQUIRED reason=" + (pendingRead.reason || pendingRead.status));
    return { action: "RECOVERY_REQUIRED", reason: pendingRead.reason || pendingRead.status };
  }
  if (pendingRead.status === "ok") {
    const pending = pendingRead.pending;
    if (pending.matchId !== options.matchId) {
      console.log("FORREF_RECOVERY outcome=RECOVERY_REQUIRED reason=pending-match");
      return { action: "RECOVERY_REQUIRED", reason: "pending-match", captureIntentId: pending.captureIntentId };
    }
    bind(ui, pending);
    const found = (loaded.entries || []).find((entry) => entry.captureIntentId === pending.captureIntentId);
    if (loaded.status !== "ok" && loaded.status !== "empty") {
      console.log("FORREF_RECOVERY outcome=RECOVERY_REQUIRED reason=" + (loaded.reason || loaded.status));
      return {
        action: "RECOVERY_REQUIRED",
        reason: loaded.reason || loaded.status,
        captureIntentId: pending.captureIntentId,
        recordId: pending.recordId,
        scoringTeamId: pending.scoringTeamId,
      };
    }
    if (found && (found.recordId !== pending.recordId || found.scoringTeamId !== pending.scoringTeamId)) {
      return { action: "RECOVERY_REQUIRED", reason: "intent-conflict", captureIntentId: pending.captureIntentId };
    }
    if (found) {
      return {
        action: "ALREADY_RECORDED",
        captureIntentId: pending.captureIntentId,
        recordId: pending.recordId,
        scoringTeamId: pending.scoringTeamId,
        entries: loaded.entries,
      };
    }
    return {
      action: "RETRY",
      captureIntentId: pending.captureIntentId,
      recordId: pending.recordId,
      scoringTeamId: pending.scoringTeamId,
      entries: loaded.entries,
    };
  }
  if (options.userAction !== true) return { action: "IDLE" };
  const identity = options.allocate ? options.allocate() : allocateGoalIdentity();
  const pending = {
    matchId: options.matchId,
    scoringTeamId: options.scoringTeamId,
    captureIntentId: identity.captureIntentId,
    recordId: identity.recordId,
  };
  const established = establishPending(options.pendingStore, pending);
  if (!established.ok) return { action: "UNCERTAIN", reason: "pending-readback" };
  bind(ui, pending);
  return {
    action: "READY",
    captureIntentId: pending.captureIntentId,
    recordId: pending.recordId,
    scoringTeamId: pending.scoringTeamId,
  };
}

export function commitGoalCapture(options) {
  const resumed = resumeGoalCapture(Object.assign({}, options, { userAction: false }));
  if (resumed.action === "ALREADY_RECORDED") {
    const cleared = clearPending(options.pendingStore);
    if (!cleared.ok) {
      return {
        ok: false,
        uncertain: true,
        outcome: "UNCERTAIN",
        reason: "pending-clear",
        captureIntentId: resumed.captureIntentId,
        saved: false,
        d1Certified: false,
        authoritativeCaptureAdmitted: false,
      };
    }
    return {
      ok: true,
      uncertain: false,
      outcome: "LOCAL_RECORD_VERIFIED",
      reason: "idempotent",
      captureIntentId: resumed.captureIntentId,
      entries: resumed.entries,
      saved: false,
      d1Certified: false,
      authoritativeCaptureAdmitted: false,
    };
  }
  if (resumed.action !== "RETRY") {
    return {
      ok: false,
      uncertain: resumed.action === "UNCERTAIN" || resumed.action === "RECOVERY_REQUIRED",
      outcome: resumed.action,
      reason: resumed.reason || resumed.action,
      captureIntentId: resumed.captureIntentId || "",
      saved: false,
      d1Certified: false,
      authoritativeCaptureAdmitted: false,
    };
  }
  const result = options.journal.append({
    captureIntentId: resumed.captureIntentId,
    recordId: resumed.recordId,
    scoringTeamId: resumed.scoringTeamId,
  });
  if (result.ok) {
    const cleared = clearPending(options.pendingStore);
    if (!cleared.ok) {
      return {
        ok: false,
        uncertain: true,
        outcome: "UNCERTAIN",
        reason: "pending-clear",
        captureIntentId: resumed.captureIntentId,
        entries: result.entries,
        saved: false,
        d1Certified: false,
        authoritativeCaptureAdmitted: false,
      };
    }
  }
  return result;
}

export function openLocalGoal(fs, matchId) {
  const admitted = admitStoredGoal(fs, matchId || "");
  if (!admitted.localCandidate) {
    return { admitted: admitted, journal: null, pendingStore: null, journalPath: "" };
  }
  const selected = selectGoalJournalPath(fs, admitted.matchId);
  const journalContext = {
    matchId: admitted.matchId,
    principalId: admitted.principalId,
    writerDeviceId: admitted.writerDeviceId,
    localInstallationId: admitted.localInstallationId,
    homeTeamId: admitted.homeTeamId,
    awayTeamId: admitted.awayTeamId,
    authorityActivated: true,
    generation: 1,
  };
  return {
    admitted: admitted,
    journal: createGoalJournal(createFileGoalStore(fs, selected.path), journalContext),
    pendingStore: createFilePendingStore(fs, pendingName(admitted.matchId)),
    journalPath: selected.path,
    journalContext: journalContext,
  };
}
