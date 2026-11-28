import { getDeviceInfo } from "@zos/device";
import { readFileSync, readdirSync, writeFileSync } from "@zos/fs";
import { back } from "@zos/router";
import { appPlugin } from "@zeppos/zml/3.0/module/messaging/plugin/app";
import { bindBack, button, clear, logDevice, paintBase, textAt } from "../../../utils/chrome";
import { PROVISION_ADMISSION_FILE, PROVISION_ROOT_FILE } from "../../../utils/goal_admission";
import { readStoredText } from "../../../utils/goal_journal";
import { createFileProvisionStore } from "../../../utils/provision_transport";
import { createWatchProvisionAdmission } from "../../../utils/watch_provision";
import { attachDeviceMessaging, nextLinkVisit, retireLinkVisit } from "../../../utils/device_messaging";
import { deviceBuildLine } from "../../../utils/build_stamp";
import { ENROLL_ADMISSION_FILE, ENROLL_CORRELATION_FILE, ENROLL_ROOT_FILE, PAIR_ADMISSION_FILE, PAIR_CORRELATION_FILE, PAIR_ROOT_FILE, PROVISION_CORRELATION_FILE, PROVISION_PAGE_TIMEOUT_MS, TRANSFER_ADMISSION_FILE, TRANSFER_CORRELATION_FILE, TRANSFER_ROOT_FILE, confirmPairing, readProvisionEvidence, receiveMatch, runPrepare } from "../../../utils/provision_bridge";
import {
  installationLineSize,
  resolveInstallationCard,
  splitInstallationId,
} from "../../../utils/installation_label";
import { witnessFromInfo } from "../../../utils/identity_witness";
import { durablePath, readDurableText, resolveInstallation } from "../../../utils/installation_continuity";
import { place } from "../../../utils/geometry";
import { t } from "../../../utils/text";
import { ACCENT, TEXT_PRIMARY, TEXT_WARNING } from "../../../utils/theme";

function fileStore(name) {
  const path = durablePath(name);
  return {
    read() {
      return readDurableText({ readFileSync: readFileSync }, name);
    },
    write(text) {
      try {
        writeFileSync({ path: path, data: text, options: { encoding: "utf8" } });
      } catch (err) {
        return { status: "unreadable" };
      }
      return readStoredText({ readFileSync: readFileSync }, path);
    },
  };
}

function provisionFiles() {
  return {
    readFileSync(request) {
      const name = String(request && request.path ? request.path : "").replace(/^data:\/\//, "");
      const read = readDurableText({ readFileSync: readFileSync }, name);
      if (!read || read.status === "absent") throw new Error("ENOENT: not found");
      if (read.status !== "ok") throw new Error("unreadable");
      return read.text;
    },
    writeFileSync(request) {
      const name = String(request && request.path ? request.path : "").replace(/^data:\/\//, "");
      writeFileSync({
        path: durablePath(name),
        data: request.data,
        options: request.options || { encoding: "utf8" },
      });
    },
  };
}

function detail(err) {
  const message = err && err.message ? String(err.message) : String(err || "exception");
  return message.slice(0, 120);
}

function runningApp() {
  const lookup = globalThis.getApp;
  return typeof lookup === "function" ? lookup() : null;
}

function statusLabel(status) {
  if (status === "identity") return t("installationReady");
  if (status === "prepared") return t("stagePrepared");
  if (status === "verified") return t("pairVerified");
  if (status === "config-verified") return t("configVerified");
  if (status === "phone-unreachable") return t("pairUnreachable");
  if (status === "writer-kept") return t("pairWriterKept");
  if (status === "locked") return t("stageLocked");
  if (status === "activated") return t("stageActivated");
  if (status === "recovery-required") return t("recoveryRequired");
  return String(status || "");
}

function currentWitness() {
  try {
    return witnessFromInfo(getDeviceInfo());
  } catch (err) {
    return witnessFromInfo(null);
  }
}

function historicalCorrelationSnapshot() {
  const read = readDurableText({ readFileSync: readFileSync }, PROVISION_CORRELATION_FILE);
  if (!read || read.status === "absent") return { status: "absent", text: "", bytes: 0 };
  if (read.status !== "ok") return { status: "unreadable", text: "", bytes: 0 };
  const text = String(read.text);
  return { status: "present", text: text, bytes: text.length };
}

function logEnrollmentCompare(beforeText) {
  const after = historicalCorrelationSnapshot();
  const same = after.text === String(beforeText || "");
  console.log("FORREF_ENROLL tx=compare historical-same=" + (same ? "1" : "0") + " bytes=" + after.bytes);
}

function outcomeStatus(view) {
  if (view && view.result) return view.result;
  if (view && view.reason === "recovery-required") return "recovery-required";
  if (!view) return "refused";
  if (view.ok && view.transport === "recorded") return "activated";
  if (view.stage === "report") return "activated";
  if (view.durable === true && view.transport === "locked") return "locked";
  if ((view.ok && view.transport === "prepared") || view.stage === "verified" || view.stage === "prepared") return "prepared";
  return view.reason || "refused";
}

Page({
  onInit() {
    this._view = { ok: false, id: "", reason: "", status: "" };
    this._busy = false;
    this._closed = false;
    this._visit = 0;
    try {
      this._visit = nextLinkVisit(runningApp());
    } catch (err) {
      console.log("FORREF_PROVISION tx=recover reason=visit detail=" + detail(err));
    }
    console.log("FORREF_PROVISION page=init visit=" + this._visit);
  },
  onDestroy() {
    this._closed = true;
    console.log("FORREF_PROVISION page=destroy visit=" + this._visit);
    try {
      const retired = retireLinkVisit(runningApp(), this._visit);
      console.log("FORREF_PROVISION tx=retire visit=" + this._visit + " owner=" + (retired ? "cleared" : "kept"));
    } catch (err) {
      console.log("FORREF_PROVISION tx=recover reason=destroy detail=" + detail(err));
    }
  },
  build() {
    console.log("FORREF_PROVISION page=build");
    console.log(deviceBuildLine());
    try {
      console.log(currentWitness().line);
    } catch (err) {
      console.log("FORREF_WITNESS kind=absent class=unavailable len=0");
    }
    try {
      bindBack(false);
    } catch (err) {
      console.log("FORREF_PROVISION tx=recover reason=back detail=" + detail(err));
    }
    try {
      const identified = resolveInstallation({ readFileSync: readFileSync, writeFileSync: writeFileSync, readdirSync: readdirSync });
      console.log(identified.line);
      let status = identified.ok ? "identity" : "unavailable";
      if (identified.ok) {
        const evidence = readProvisionEvidence(
          identified,
          fileStore(PROVISION_CORRELATION_FILE),
          createWatchProvisionAdmission(
            createFileProvisionStore(provisionFiles(), PROVISION_ROOT_FILE, PROVISION_ADMISSION_FILE),
          ),
        );
        console.log(evidence.line);
        if (evidence.phase === "verified") status = "prepared";
        if (evidence.phase === "activated" || evidence.phase === "reported") status = "activated";
      }
      this._view = {
        ok: identified.ok,
        id: identified.id || "",
        reason: identified.reason || "",
        status: status,
      };
      console.log(
        "FORREF_PROVISION outcome=" +
          (identified.ok ? "WATCH_IDENTIFIED" : "RECOVERY_REQUIRED") +
          " reason=" +
          (identified.reason || "") +
          " created=" +
          (identified.created ? "1" : "0"),
      );
    } catch (err) {
      this._view = { ok: false, id: "", reason: "exception", status: "unavailable" };
      console.log("FORREF_PROVISION tx=recover reason=exception detail=" + detail(err));
    }
    try {
      this.paint();
    } catch (err) {
      console.log("FORREF_PROVISION tx=recover reason=paint detail=" + detail(err));
      this.paintFallback();
    }
  },
  paint() {
    const m = logDevice("provision");
    clear();
    paintBase(m);
    const view = this._view || { ok: false, id: "", reason: "exception", status: "unavailable" };
    const card = resolveInstallationCard(m);
    console.log(
      "FORREF_PROVISION device width=" +
        m.width +
        " height=" +
        m.height +
        " round=" +
        (m.round ? "1" : "0") +
        " layout=" +
        (card.fallback ? "fallback" : "card") +
        " lineY=" +
        card.line.y +
        " lineH=" +
        card.line.h +
        " lineW=" +
        card.line.w,
    );
    textAt(card.title.x, card.title.y, card.title.w, card.title.h, t("provision"), Math.round(m.width * 0.045), ACCENT);
    if (view.ok && view.status === "config-verified") {
      const minutes = view.minutes || 0;
      textAt(card.line.x, card.line.y, card.line.w, card.line.h, view.summaryHome || "", 22, TEXT_PRIMARY);
      textAt(card.line2.x, card.line2.y, card.line2.w, card.line2.h, view.summaryAway || "", 22, TEXT_PRIMARY);
      textAt(card.status.x, card.status.y, card.status.w, card.status.h, minutes + " + " + minutes + "  " + t("configVerified"), 18, TEXT_WARNING);
    } else if (view.ok && view.id) {
      const lines = splitInstallationId(view.id);
      const size = installationLineSize(card.line.w, card.line.h, lines[0] || view.id);
      textAt(card.line.x, card.line.y, card.line.w, card.line.h, lines[0] || "", size, TEXT_PRIMARY);
      textAt(card.line2.x, card.line2.y, card.line2.w, card.line2.h, lines[1] || "", size, TEXT_PRIMARY);
      console.log("FORREF_PROVISION installation=" + view.id + " lines=" + lines.length + " size=" + size);
      textAt(card.status.x, card.status.y, card.status.w, card.status.h, statusLabel(view.status), 20, TEXT_WARNING);
    } else {
      textAt(card.line.x, card.line.y, card.line.w, card.line.h, t("installationUnavailable"), 22, TEXT_WARNING);
      textAt(card.line2.x, card.line2.y, card.line2.w, card.line2.h, view.reason || "exception", 20, TEXT_WARNING);
      console.log("FORREF_PROVISION tx=recover reason=" + (view.reason || "unavailable"));
      textAt(card.status.x, card.status.y, card.status.w, card.status.h, t("installationUnavailable"), 18, TEXT_WARNING);
    }
    button(card.action.x, card.action.y, card.action.w, card.action.h, t("provision"), () => this.start(), null, "provision-start", m);
    button(card.back.x, card.back.y, card.back.w, card.back.h, t("back"), () => back(), null, "provision-back", m);
    const confirm = place(m, card.back.y + card.back.h + 6, 40, card.back.w);
    if (confirm.ok) {
      button(confirm.x, confirm.y, confirm.w, confirm.h, t("confirmPairing"), () => this.confirmPairing(), null, "provision-confirm", m);
      const receive = place(m, confirm.y + confirm.h + 6, 40, confirm.w);
      if (receive.ok) {
        button(receive.x, receive.y, receive.w, receive.h, t("receiveMatch"), () => this.receiveMatch(), null, "provision-receive", m);
      } else {
        console.log("FORREF_TRANSFER tx=layout reason=hidden");
      }
    } else {
      console.log("FORREF_PAIR tx=layout reason=hidden");
    }
  },
  paintFallback() {
    try {
      const m = logDevice("provision");
      clear();
      paintBase(m);
      textAt(16, 80, m.width - 32, 36, t("provision"), 24, ACCENT);
      textAt(16, 124, m.width - 32, 40, t("installationUnavailable"), 22, TEXT_WARNING);
      button(16, 220, m.width - 32, 48, t("back"), () => back(), null, "provision-back", m);
    } catch (err) {
      console.log("FORREF_PROVISION tx=recover reason=fallback detail=" + detail(err));
    }
  },
  start() {
    this.begin("historical");
  },
  confirmPairing() {
    const before = historicalCorrelationSnapshot();
    this._historicalText = before.text;
    console.log("FORREF_PAIR tx=preflight historical=" + before.status + " bytes=" + before.bytes);
    this.begin("pair");
  },
  receiveMatch() {
    const before = historicalCorrelationSnapshot();
    this._historicalText = before.text;
    console.log("FORREF_TRANSFER tx=preflight historical=" + before.status + " bytes=" + before.bytes);
    this.begin("transfer");
  },
  enrollWitness() {
    const before = historicalCorrelationSnapshot();
    this._historicalText = before.text;
    console.log("FORREF_ENROLL tx=preflight historical=" + before.status + " bytes=" + before.bytes);
    this.begin("enroll");
  },
  begin(kind) {
    if (this._busy || this._closed) return;
    this._busy = true;
    const kept = this._view && this._view.ok && this._view.id ? this._view.id : "";
    if (!kept) {
      this._busy = false;
      console.log("FORREF_PROVISION tx=recover reason=" + ((this._view && this._view.reason) || "recovery") + " installation=");
      return;
    }
    const enroll = kind === "enroll";
    const pairing = kind === "pair";
    const transfer = kind === "transfer";
    const isolated = enroll || pairing || transfer;
    const app = runningApp();
    if (!app || !app.globalData) {
      this.finishPrepare(kept, { ok: false, reason: "app" });
      return;
    }
    let messaging = null;
    try {
      messaging = attachDeviceMessaging(app, appPlugin, this._visit);
    } catch (err) {
      console.log("FORREF_PROVISION tx=recover reason=init detail=" + detail(err) + " installation=" + kept);
    }
    if (!messaging) {
      this.finishPrepare(kept, { ok: false, reason: "device:messaging", hop: "device", category: "messaging" });
      return;
    }
    const namespace = transfer ? "transfer" : pairing ? "pair" : enroll ? "enroll" : "historical";
    console.log("FORREF_PROVISION messaging=ready visit=" + this._visit + " installation=" + kept + " namespace=" + namespace);
    const requestStore = transfer
      ? fileStore(TRANSFER_CORRELATION_FILE)
      : pairing
        ? fileStore(PAIR_CORRELATION_FILE)
        : enroll
          ? fileStore(ENROLL_CORRELATION_FILE)
          : fileStore(PROVISION_CORRELATION_FILE);
    const rootFile = transfer ? TRANSFER_ROOT_FILE : pairing ? PAIR_ROOT_FILE : enroll ? ENROLL_ROOT_FILE : PROVISION_ROOT_FILE;
    const admissionFile = transfer ? TRANSFER_ADMISSION_FILE : pairing ? PAIR_ADMISSION_FILE : enroll ? ENROLL_ADMISSION_FILE : PROVISION_ADMISSION_FILE;
    const deps = {
      loadInstallation: () => ({ ok: true, id: kept, reason: "" }),
      requestStore: requestStore,
      admission: createWatchProvisionAdmission(
        createFileProvisionStore(provisionFiles(), rootFile, admissionFile),
      ),
      request: (message) => messaging.request(message, { timeout: PROVISION_PAGE_TIMEOUT_MS }),
      readWitness: () => {
        const read = currentWitness();
        console.log(read.line);
        return read.witness;
      },
      attempts: 3,
      wait: () => new Promise((resolve) => {
        if (typeof setTimeout === "function") setTimeout(resolve, 300);
        else resolve();
      }),
    };
    const pending = transfer ? receiveMatch(deps) : pairing ? confirmPairing(deps) : runPrepare({
      loadInstallation: deps.loadInstallation,
      requestStore: deps.requestStore,
      admission: deps.admission,
      request: deps.request,
      readWitness: deps.readWitness,
    });
    pending.then((view) => {
      if (isolated) logEnrollmentCompare(this._historicalText);
      this.finishPrepare(kept, view);
    }).catch((err) => {
      const text = detail(err).toLowerCase();
      const category = text.indexOf("timeout") >= 0 || text.indexOf("timed out") >= 0
        ? "timeout"
        : text.indexOf("permission") >= 0 || text.indexOf("denied") >= 0
          ? "permission"
          : "transport";
      console.log("FORREF_PROVISION tx=recover hop=device category=" + category + " reason=" + category + " installation=" + kept);
      if (isolated) logEnrollmentCompare(this._historicalText);
      this.finishPrepare(kept, { ok: false, reason: "device:" + category, hop: "device", category: category });
    });
  },
  finishPrepare(kept, view) {
    this._busy = false;
    const id = kept || (view && view.installationId) || "";
    const status = outcomeStatus(view);
    const named = status === "config-verified" || status === "prepared" || status === "locked" || status === "activated";
    if (this._closed) {
      console.log("FORREF_PROVISION tx=drop installation=" + id + " reason=" + (view && view.reason ? view.reason : ""));
      return;
    }
    this._view = {
      ok: !!id,
      id: id,
      reason: view && view.reason ? view.reason : "",
      status: status,
      summaryHome: view && view.summaryHome ? view.summaryHome : "",
      summaryAway: view && view.summaryAway ? view.summaryAway : "",
      minutes: view && view.minutes ? view.minutes : 0,
    };
    const outcome = status === "config-verified" ? "CONFIG_VERIFIED" : status === "prepared" ? "PREPARED" : status === "locked" ? "LOCKED" : status === "activated" ? "ACTIVATED" : "REFUSED";
    console.log(
      "FORREF_PROVISION outcome=" + outcome +
        " installation=" + id +
        " request=" + ((view && view.requestId) || "") +
        " match=" + ((view && view.matchId) || "") +
        " hash=" + ((view && view.contentHash) || "") +
        " generation=1" +
        " canonical=" + (named ? "accepted" : "rejected") +
        " hop=" + ((view && view.hop) || "") +
        " category=" + ((view && view.category) || "") +
        " reason=" + ((view && view.reason) || "") +
        " detail=" + ((view && view.detail) || ""),
    );
    console.log("FORREF_D1 outcome=UNCERTIFIED reason=watch-storage-not-certified");
    try {
      this.paint();
    } catch (err) {
      console.log("FORREF_PROVISION tx=recover reason=paint detail=" + detail(err));
    }
  },
});
