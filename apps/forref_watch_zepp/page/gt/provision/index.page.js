import { readFileSync, writeFileSync } from "@zos/fs";
import { back } from "@zos/router";
import { bindBack, button, clear, logDevice, paintBase, textAt } from "../../../utils/chrome";
import { INSTALLATION_FILE } from "../../../utils/installation_id";
import { PROVISION_ADMISSION_FILE, PROVISION_ROOT_FILE } from "../../../utils/goal_admission";
import { readStoredText } from "../../../utils/goal_journal";
import { createFileProvisionStore } from "../../../utils/provision_transport";
import { createWatchProvisionAdmission } from "../../../utils/watch_provision";
import { PROVISION_CORRELATION_FILE, PROVISION_PAGE_TIMEOUT_MS, runHandshake } from "../../../utils/provision_bridge";
import {
  installationLineSize,
  resolveInstallationCard,
  splitInstallationId,
} from "../../../utils/installation_label";
import { messagingUsable, prepareInstallation } from "../../../utils/provision_identity";
import { t } from "../../../utils/text";
import { ACCENT, TEXT_PRIMARY, TEXT_WARNING } from "../../../utils/theme";

function fileStore(path) {
  return {
    read() {
      return readStoredText({ readFileSync: readFileSync }, path);
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

function readMessaging() {
  try {
    const lookup = globalThis.getApp;
    const app = typeof lookup === "function" ? lookup() : null;
    const data = app && app._options && app._options.globalData;
    if (!messagingUsable(data)) return null;
    return data.messaging;
  } catch (err) {
    console.log("FORREF_PROVISION tx=recover reason=messaging detail=" + detail(err));
    return null;
  }
}

Page({
  onInit() {
    this._view = { ok: false, id: "", reason: "", status: "" };
    console.log("FORREF_PROVISION page=init");
  },
  build() {
    console.log("FORREF_PROVISION page=build");
    try {
      bindBack(false);
    } catch (err) {
      console.log("FORREF_PROVISION tx=recover reason=back detail=" + detail(err));
    }
    try {
      const identified = prepareInstallation(fileStore(INSTALLATION_FILE));
      this._view = {
        ok: identified.ok,
        id: identified.id || "",
        reason: identified.reason || "",
        status: identified.ok ? "identity" : "unavailable",
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
      textAt(card.status.x, card.status.y, card.status.w, card.status.h, view.status === "identity" ? t("installationReady") : String(view.status || ""), 20, TEXT_WARNING);
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
    const kept = this._view && this._view.id ? this._view.id : "";
    const messaging = readMessaging();
    if (!messaging) {
      console.log("FORREF_PROVISION tx=recover reason=messaging installation=" + kept);
      this._view = { ok: !!kept, id: kept, reason: kept ? "" : "messaging", status: "messaging" };
      try {
        this.paint();
      } catch (err) {
        console.log("FORREF_PROVISION tx=recover reason=paint detail=" + detail(err));
      }
      return;
    }
    const admission = createWatchProvisionAdmission(
      createFileProvisionStore({ readFileSync: readFileSync, writeFileSync: writeFileSync }, PROVISION_ROOT_FILE, PROVISION_ADMISSION_FILE),
    );
    runHandshake({
      loadInstallation: () => prepareInstallation(fileStore(INSTALLATION_FILE)),
      requestStore: fileStore(PROVISION_CORRELATION_FILE),
      admission: admission,
      request: (message) => messaging.request(message, { timeout: PROVISION_PAGE_TIMEOUT_MS }),
    }).then((view) => {
      const id = kept || (view && view.installationId) || "";
      this._view = { ok: !!id, id: id, reason: view && view.reason ? view.reason : "", status: view && view.ok ? "recorded" : (view && view.reason) || "refused" };
      console.log("FORREF_PROVISION outcome=" + (view && view.ok ? "WATCH_ACTIVATED_V1" : "REFUSED") + " reason=" + ((view && view.reason) || ""));
      console.log("FORREF_D1 outcome=UNCERTIFIED reason=watch-storage-not-certified");
      this.paint();
    }).catch((err) => {
      console.log("FORREF_PROVISION tx=recover reason=request detail=" + detail(err) + " installation=" + kept);
      this._view = { ok: !!kept, id: kept, reason: kept ? "" : "request", status: "request" };
      this.paint();
    });
  },
});
