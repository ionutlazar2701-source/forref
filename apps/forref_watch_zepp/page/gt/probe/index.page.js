import * as hmUI from "@zos/ui";
import { readFileSync, writeFileSync } from "@zos/fs";
import { BasePage } from "@zeppos/zml/base-page";
import { bindBack, logDevice, paintBase, textAt } from "../../../utils/chrome";
import {
  GET_CONFIGURATION,
  PROBE_FILE,
  acceptPayload,
  receiptRequest,
  storeRecord,
} from "../../../utils/config_probe.js";
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
        path: PROBE_FILE,
        data: text,
        options: { encoding: "utf8" },
      });
    },
    read() {
      return asText(
        readFileSync({ path: PROBE_FILE, options: { encoding: "utf8" } })
      );
    },
  };
}

Page(
  BasePage({
    onInit() {
      console.log("FORREF_PROBE_A page=init");
      this._result = null;
      this.request({ method: GET_CONFIGURATION, params: {} })
        .then((data) => {
          const accepted = acceptPayload(data);
          if (!accepted.ok) {
            this.finish(false, accepted.reason);
            return null;
          }
          const stored = storeRecord(deviceIo(), accepted.record);
          if (!stored.stored) {
            this.finish(false, stored.reason);
            return null;
          }
          return this.request(receiptRequest(accepted.record)).then((receipt) => {
            const recorded = receipt && receipt.disposition === "recorded";
            this.finish(recorded, recorded ? accepted.record.contentHash : "receipt");
          });
        })
        .catch(() => {
          this.finish(false, "request");
        });
    },
    build() {
      const m = logDevice("probe-a");
      bindBack(true);
      paintBase(m);
      textAt(m.pad, m.originY + 36, m.contentW, 36, t("probeA"), 28, TEXT_PRIMARY);
      this.statusNode = textAt(
        m.pad,
        m.originY + 88,
        m.contentW,
        80,
        t("probeWaiting"),
        24,
        TEXT_PRIMARY
      );
      this.paintStatus();
      textAt(
        m.pad,
        m.originY + 180,
        m.contentW,
        72,
        t("probeStatic"),
        20,
        TEXT_PRIMARY
      );
    },
    finish(stored, detail) {
      this._result = { stored: stored, detail: detail };
      const line = stored ? "FORREF_PROBE_A stored=yes" : "FORREF_PROBE_A stored=no";
      console.log(line + " detail=" + detail);
      this.paintStatus();
    },
    paintStatus() {
      if (!this.statusNode || !this._result) {
        return;
      }
      this.statusNode.setProperty(
        hmUI.prop.TEXT,
        this._result.stored ? t("probeStored") : t("probeNotStored")
      );
      this.statusNode.setProperty(
        hmUI.prop.COLOR,
        this._result.stored ? TEXT_PRIMARY : TEXT_WARNING
      );
    },
  })
);
