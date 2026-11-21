import * as hmUI from "@zos/ui";
import { readFileSync, writeFileSync } from "@zos/fs";
import { BasePage } from "@zeppos/zml/base-page";
import { bindBack, logDevice, paintBase, textAt } from "../../../utils/chrome";
import {
  GET_LOCAL_CONFIGURATION,
  LOCAL_FILE,
  applyFetch,
  readStored,
  receiptRequest,
  teamLabel,
} from "../../../utils/local_bridge.js";
import { t } from "../../../utils/text";
import { TEXT_PRIMARY, TEXT_WARNING } from "../../../utils/theme";

function asText(value) {
  if (typeof value === "string") {
    return value;
  }
  if (value && typeof value.data === "string") {
    return value.data;
  }
  return "";
}

function deviceIo() {
  return {
    write(text) {
      writeFileSync({
        path: LOCAL_FILE,
        data: text,
        options: { encoding: "utf8" },
      });
    },
    read() {
      return asText(
        readFileSync({ path: LOCAL_FILE, options: { encoding: "utf8" } })
      );
    },
  };
}

function nameLine(names) {
  if (!names) {
    return "";
  }
  return (
    teamLabel(names.home, t("localUnset")) +
    " — " +
    teamLabel(names.away, t("localUnset"))
  );
}

Page(
  BasePage({
    onInit() {
      console.log("FORREF_B1 page=init");
      this._result = null;
      this.request({ method: GET_LOCAL_CONFIGURATION, params: {} })
        .then((data) => {
          const applied = applyFetch(data, deviceIo());
          if (!applied.stored) {
            this.finish(applied);
            return null;
          }
          return this.request(receiptRequest(applied.record)).then((receipt) => {
            applied.receipt = Boolean(receipt && receipt.disposition === "recorded");
            this.finish(applied);
          });
        })
        .catch(() => {
          const saved = readStored(deviceIo());
          this.finish({
            stored: false,
            detail: "request",
            names: saved.ok
              ? { home: saved.record.homeTeamName, away: saved.record.awayTeamName }
              : null,
            savedCopy: saved.ok,
            receipt: false,
          });
        });
    },
    build() {
      const m = logDevice("local-bridge");
      bindBack(true);
      paintBase(m);
      textAt(m.pad, m.originY + 28, m.contentW, 32, t("localBridge"), 24, TEXT_PRIMARY);
      this.statusNode = textAt(
        m.pad,
        m.originY + 68,
        m.contentW,
        36,
        t("localWaiting"),
        22,
        TEXT_PRIMARY
      );
      this.namesNode = textAt(m.pad, m.originY + 112, m.contentW, 96, "", 28, TEXT_PRIMARY);
      this.savedNode = textAt(m.pad, m.originY + 214, m.contentW, 36, "", 18, TEXT_PRIMARY);
      this.paintResult();
    },
    finish(result) {
      this._result = result;
      const names = nameLine(result.names);
      console.log(
        "FORREF_B1 stored=" +
          (result.stored ? "yes" : "no") +
          " detail=" +
          result.detail +
          " receipt=" +
          (result.receipt ? "yes" : "no") +
          " savedCopy=" +
          (result.savedCopy ? "yes" : "no") +
          " names=" +
          names
      );
      this.paintResult();
    },
    paintResult() {
      if (!this.statusNode || !this._result) {
        return;
      }
      this.statusNode.setProperty(
        hmUI.prop.TEXT,
        this._result.stored ? t("localStored") : t("localNotStored")
      );
      this.statusNode.setProperty(
        hmUI.prop.COLOR,
        this._result.stored ? TEXT_PRIMARY : TEXT_WARNING
      );
      this.namesNode.setProperty(hmUI.prop.TEXT, nameLine(this._result.names));
      this.savedNode.setProperty(
        hmUI.prop.TEXT,
        this._result.savedCopy ? t("localSaved") : this._result.stored ? "" : t("localOffline")
      );
    },
  })
);
