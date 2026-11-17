import { back } from "@zos/router";
import { getLanguage } from "@zos/settings";
import { bindBack, clear, logDevice, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";
import { analyzeTrack } from "../../../lib/analytics";
import { createJournal } from "../../../lib/journal";
import { deviceAdapter } from "../../../utils/device_fs";

function code() {
  try {
    return getLanguage();
  } catch (err) {
    return -1;
  }
}

function paint() {
  const m = logDevice("track");
  clear();
  const lang = code();
  const loaded = createJournal(deviceAdapter()).read();
  if (!loaded.ok) {
    stack(m, t("track", lang), [
      { label: t("corrupt", lang), color: 0xc4a35a },
      { label: t("back", lang), name: "sens-back", action: () => back() },
    ]);
    return;
  }
  if (loaded.entries.length === 0) {
    stack(m, t("track", lang), [
      { label: t("noSamples", lang), color: 0xc4a35a },
      { label: t("notMatch", lang) },
      { label: t("back", lang), name: "sens-back", action: () => back() },
    ]);
    return;
  }
  const report = analyzeTrack(loaded.entries);
  const distance = Math.round(report.distanceMeters) + " m " + t("experimental", lang);
  const speed = report.maxSpeedReliable ? report.maxSpeedMps.toFixed(1) + " m/s " + t("experimental", lang) : t("noReliableSpeed", lang);
  const missing = t("gap", lang) + " " + report.gaps.length + " / " + Math.round(report.missingMs / 1000) + "s";
  stack(m, t("track", lang), [
    { label: distance, color: 0xc4a35a },
    { label: speed },
    { label: missing },
    { label: t("distanceUnresolved", lang) },
    { label: "HR " + (report.hrCoverage == null ? t("hrUnavailable", lang) : Math.round(report.hrCoverage * 100) + "%") },
    { label: t("notMatch", lang) },
    { label: t("back", lang), name: "sens-back", action: () => back() },
  ]);
}

Page({
  build() {
    bindBack(false);
    paint();
  },
});
