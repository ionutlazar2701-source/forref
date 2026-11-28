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
import { PROVISION_CORRELATION_FILE, PROVISION_PAGE_TIMEOUT_MS, readProvisionEvidence, runSideDiagnostic } from "../../../utils/provision_bridge";
import {
  installationLineSize,
  resolveInstallationCard,
  splitInstallationId,
} from "../../../utils/installation_label";
import { readDurableText, resolveInstallation } from "../../../utils/installation_continuity";
import { t } from "../../../utils/text";
import { ACCENT, TEXT_PRIMARY, TEXT_WARNING } from "../../../utils/theme";

function fileStore(path) {
  return {
    read() {
      return readDurableText({ readFileSync: readFileSync }, path);
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
  if (status === "locked") return t("stageLocked");
  if (status === "activated") return t("stageActivated");
  return String(status || "");
}

function outcomeStatus(view) {
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
            createFileProvisionStore({ readFileSync: readFileSync, writeFileSync: writeFileSync }, PROVISION_ROOT_FILE, PROVISION_ADMISSION_FILE),
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
    if (view.ok && view.id) {
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
    if (this._busy || this._closed) return;
    this._busy = true;
    const kept = this._view && this._view.id ? this._view.id : "";
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
    console.log("FORREF_PROVISION messaging=ready visit=" + this._visit + " installation=" + kept);
    runSideDiagnostic({
      request: (message) => messaging.request(message, { timeout: PROVISION_PAGE_TIMEOUT_MS }),
    }).then((view) => {
      this.finishPrepare(kept, view);
    }).catch((err) => {
      const text = detail(err).toLowerCase();
      const category = text.indexOf("timeout") >= 0 || text.indexOf("timed out") >= 0
        ? "timeout"
        : text.indexOf("permission") >= 0 || text.indexOf("denied") >= 0
          ? "permission"
          : "transport";
      console.log("FORREF_PROVISION tx=recover hop=device category=" + category + " reason=" + category + " installation=" + kept);
      this.finishPrepare(kept, { ok: false, reason: "device:" + category, hop: "device", category: category });
    });
  },
  finishPrepare(kept, view) {
    this._busy = false;
    const id = kept || (view && view.installationId) || "";
    const status = outcomeStatus(view);
    const named = status === "prepared" || status === "locked" || status === "activated";
    if (this._closed) {
      console.log("FORREF_PROVISION tx=drop installation=" + id + " reason=" + (view && view.reason ? view.reason : ""));
      return;
    }
    this._view = {
      ok: !!id,
      id: id,
      reason: view && view.reason ? view.reason : "",
      status: status,
    };
    const outcome = status === "prepared" ? "PREPARED" : status === "locked" ? "LOCKED" : status === "activated" ? "ACTIVATED" : "REFUSED";
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
