import { readFileSync, writeFileSync } from "@zos/fs";
import { BasePage } from "@zeppos/zml/base-page";
import { back } from "@zos/router";
import { bindBack, clear, logDevice, stack } from "../../../utils/chrome";
import { INSTALLATION_FILE, loadInstallationId } from "../../../utils/installation_id";
import { PROVISION_ADMISSION_FILE, PROVISION_ROOT_FILE } from "../../../utils/goal_admission";
import { readStoredText } from "../../../utils/goal_journal";
import { createFileProvisionStore } from "../../../utils/provision_transport";
import { createWatchProvisionAdmission } from "../../../utils/watch_provision";
import { PROVISION_CORRELATION_FILE, PROVISION_PAGE_TIMEOUT_MS, runHandshake } from "../../../utils/provision_bridge";
import { t } from "../../../utils/text";
import { TEXT_WARNING } from "../../../utils/theme";

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

function stageLabel(stage) {
  if (stage === "prepared") return t("stagePrepared");
  if (stage === "verified") return t("stageVerified");
  if (stage === "lock") return t("stageLocked");
  if (stage === "activated" || stage === "report") return t("stageActivated");
  if (stage === "identity") return t("installationReady");
  if (stage === "missing") return t("installationMissing");
  return t("stageNone");
}

Page(
  BasePage({
    onInit() {
      this._view = null;
      console.log("FORREF_PROVISION page=init");
    },
    build() {
      bindBack(false);
      const identified = loadInstallationId(fileStore(INSTALLATION_FILE));
      this._view = {
        ok: identified.ok,
        stage: identified.ok ? "identity" : "missing",
        installationId: identified.id || "",
        reason: identified.reason || "",
        transport: "",
        matchId: "",
        homeName: "",
        awayName: "",
      };
      console.log("FORREF_PROVISION outcome=" + (identified.ok ? "WATCH_IDENTIFIED" : "RECOVERY_REQUIRED") + " reason=" + (identified.reason || ""));
      this.paint();
    },
    paint() {
      const m = logDevice("provision");
      clear();
      const view = this._view;
      const rows = [];
      if (!view) {
        rows.push({ label: t("installationMissing"), color: TEXT_WARNING });
      } else {
        rows.push({ label: view.installationId || t("installationMissing") });
        rows.push({ label: stageLabel(view.stage), color: TEXT_WARNING });
        rows.push({ label: view.matchId || t("provisionMatch") });
        rows.push({ label: (view.homeName || "—") + " — " + (view.awayName || "—") });
        rows.push({ label: t("provisionTransport") + " " + (view.transport || view.reason || "") });
      }
      rows.push({ label: t("d1Uncertified"), color: TEXT_WARNING });
      rows.push({
        label: t("provision"),
        action: () => this.start(),
        name: "provision-start",
      });
      rows.push({ label: t("back"), action: () => back(), name: "provision-back" });
      stack(m, t("provision"), rows);
    },
    start() {
      const admission = createWatchProvisionAdmission(
        createFileProvisionStore({ readFileSync: readFileSync, writeFileSync: writeFileSync }, PROVISION_ROOT_FILE, PROVISION_ADMISSION_FILE),
      );
      runHandshake({
        loadInstallation: () => loadInstallationId(fileStore(INSTALLATION_FILE)),
        requestStore: fileStore(PROVISION_CORRELATION_FILE),
        admission: admission,
        request: (message) => this.request(message, { timeout: PROVISION_PAGE_TIMEOUT_MS }),
      }).then((view) => {
        this._view = view;
        console.log("FORREF_PROVISION outcome=" + (view.ok ? "WATCH_ACTIVATED_V1" : "REFUSED") + " reason=" + (view.reason || ""));
        console.log("FORREF_D1 outcome=UNCERTIFIED reason=watch-storage-not-certified");
        this.paint();
      }).catch((err) => {
        this._view = { ok: false, stage: "transport", reason: "request", transport: "unavailable", installationId: "" };
        console.log("FORREF_PROVISION outcome=REFUSED reason=request");
        this.paint();
      });
    },
  }),
);
