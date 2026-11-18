import { back } from "@zos/router";
import { getPerformance } from "@zos/app";
import { getLanguage } from "@zos/settings";
import { bindBack, logDevice, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";
import { readPerformance } from "../../../lib/host";

function code() {
  try {
    return getLanguage();
  } catch (err) {
    return -1;
  }
}

Page({
  onInit() {
    bindBack(false);
  },
  build() {
    const lang = code();
    const diag = globalThis.__FORREF_SENS_DIAG || null;
    const perf = readPerformance({ getPerformance: getPerformance });
    const memory = perf.available && typeof perf.memory === "number" ? t("memShort", lang) + " " + perf.memory : t("perfUnavailable", lang);
    const gps = diag ? t("gpsCb", lang) + " " + diag.gpsCallbacks : t("noSession", lang);
    const hr = diag ? t("hrCb", lang) + " " + diag.hrCallbacks : t("noSession", lang);
    const queue = diag ? t("queueShort", lang) + " " + diag.queueHighWater + " " + t("dropShort", lang) + " " + diag.dropped : t("noSession", lang);
    const flush = diag ? t("flushShort", lang) + " " + diag.flushOk + " " + t("failShort", lang) + " " + diag.flushFail + " " + t("uncertified", lang) + " " + diag.uncertified : t("uncertified", lang);
    stack(logDevice("diagnostics"), t("diagnostics", lang), [
      { label: t("savedNever", lang), color: 0xc4a35a },
      { label: gps },
      { label: hr },
      { label: queue },
      { label: flush },
      { label: memory },
      { label: t("notMatch", lang) },
      { label: t("back", lang), name: "sens-back", action: () => back() },
    ]);
    console.log("FORREF_SENS_V2 diag perf=" + (perf.available ? 1 : 0) + " d1=UNCERTIFIED");
  },
});