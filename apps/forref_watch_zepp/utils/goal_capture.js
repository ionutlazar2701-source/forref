import { admitStoredGoal } from "./goal_admission.js";
import {
  acknowledgeGoalManifest,
  createFileGoalStore,
  createGoalJournal,
  goalJournalNameV2,
  manifestName,
  readStoredText,
  recoverGoalHistory,
  selectGoalJournalPath,
} from "./goal_journal.js";
import { sha256Hex } from "./sha256_hex.js";

export const PENDING_SCHEMA = "forref.watch-goal-pending.v1";

function pendingIdOk(matchId) {
  return typeof matchId === "string" && matchId.length > 0 && matchId.length <= 128 &&
    matchId === matchId.trim() && !/[\u0000-\u001f]/.test(matchId);
}

export function pendingNameV1(matchId) {
  if (typeof matchId !== "string" || !/^[A-Za-z0-9][A-Za-z0-9._-]{0,80}$/.test(matchId)) return "";
  return "forref_watch_goal_pending_v1." + matchId + ".json";
}

export function pendingName(matchId) {
  if (!pendingIdOk(matchId)) return "";
  return "forref_watch_goal_pending_v2." + sha256Hex(matchId) + ".json";
}

export function selectPendingPath(fs, matchId) {
  const v2 = pendingName(matchId);
  if (!v2) return { ok: false, path: "", reason: "match" };
  const v1 = pendingNameV1(matchId);
  const older = v1 ? readStoredText(fs, v1) : { status: "absent" };
  const newer = readStoredText(fs, v2);
  if (older.status === "unreadable" || newer.status === "unreadable") {
    return { ok: false, path: "", reason: "pending-unreadable" };
  }
  if (older.status === "ok" && newer.status === "ok") {
    return { ok: false, path: "", reason: "ambiguous-pending" };
  }
  if (older.status === "ok") return { ok: true, path: v1, reason: "" };
  return { ok: true, path: v2, reason: "" };
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

function guardedJournal(journalStore, manifestStore, pendingStore, context) {
  const journal = createGoalJournal(journalStore, context);
  function recover() {
    return recoverGoalHistory(journalStore, manifestStore, pendingStore, context);
  }
  return {
    recover: recover,
    load() {
      const recovered = recover();
      if (!recovered.ok) {
        return { status: "unreadable", entries: recovered.entries || [], reason: recovered.reason };
      }
      return journal.load();
    },
    append(command) {
      const recovered = recover();
      if (!recovered.ok) {
        console.log("FORREF_RECOVERY outcome=RECOVERY_REQUIRED reason=" + recovered.reason);
        return {
          ok: false,
          uncertain: true,
          outcome: "RECOVERY_REQUIRED",
          reason: recovered.reason,
          captureIntentId: command && command.captureIntentId || "",
          entries: recovered.entries || [],
          saved: false,
          d1Certified: false,
          authoritativeCaptureAdmitted: false,
        };
      }
      const result = journal.append(command);
      if (!result.ok) return result;
      const loaded = journal.load();
      const noted = acknowledgeGoalManifest(manifestStore, context, loaded.entries);
      if (!noted.ok) {
        console.log("FORREF_RECOVERY outcome=UNCERTAIN reason=" + noted.reason);
        return {
          ok: false,
          uncertain: true,
          outcome: "UNCERTAIN",
          reason: noted.reason,
          captureIntentId: result.captureIntentId,
          entry: result.entry,
          entries: loaded.entries,
          saved: false,
          d1Certified: false,
          authoritativeCaptureAdmitted: false,
        };
      }
      return result;
    },
  };
}

export function openLocalGoal(fs, matchId) {
  const admitted = admitStoredGoal(fs, matchId || "");
  if (!admitted.localCandidate) {
    return { ok: false, admitted: admitted, journal: null, pendingStore: null, journalPath: "", reason: admitted.reason || "provision" };
  }
  const selected = selectGoalJournalPath(fs, admitted.matchId);
  if (!selected.ok || !selected.path) {
    console.log("FORREF_RECOVERY outcome=RECOVERY_REQUIRED reason=" + (selected.reason || "journal"));
    return { ok: false, admitted: admitted, journal: null, pendingStore: null, journalPath: "", reason: selected.reason || "journal" };
  }
  const pendingSelected = selectPendingPath(fs, admitted.matchId);
  if (!pendingSelected.ok) {
    console.log("FORREF_RECOVERY outcome=RECOVERY_REQUIRED reason=" + pendingSelected.reason);
    return { ok: false, admitted: admitted, journal: null, pendingStore: null, journalPath: "", reason: pendingSelected.reason };
  }
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
  const manifestPath = manifestName(admitted.matchId);
  if (!manifestPath || !goalJournalNameV2(admitted.matchId)) {
    return { ok: false, admitted: admitted, journal: null, pendingStore: null, journalPath: "", reason: "match" };
  }
  const pendingStore = createFilePendingStore(fs, pendingSelected.path);
  const journal = guardedJournal(
    createFileGoalStore(fs, selected.path),
    createFilePendingStore(fs, manifestPath),
    pendingStore,
    journalContext,
  );
  const recovered = journal.recover();
  if (!recovered.ok) {
    console.log("FORREF_RECOVERY outcome=RECOVERY_REQUIRED reason=" + recovered.reason);
    return {
      ok: false,
      admitted: admitted,
      journal: journal,
      pendingStore: pendingStore,
      journalPath: selected.path,
      journalContext: journalContext,
      reason: recovered.reason,
    };
  }
  return {
    ok: true,
    admitted: admitted,
    journal: journal,
    pendingStore: pendingStore,
    journalPath: selected.path,
    journalContext: journalContext,
    reason: "",
  };
}
