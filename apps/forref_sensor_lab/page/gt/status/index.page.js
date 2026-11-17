import { back } from "@zos/router";
import { getLanguage } from "@zos/settings";
import { bindBack, clear, logDevice, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";
import { createJournal } from "../../../lib/journal";
import { deviceAdapter } from "../../../utils/device_fs";

function code() {
  try {
    return getLanguage();
  } catch (err) {
    return -1;
  }
}

function latest(entries, kind) {
  const rows = entries.filter((entry) => entry.kind === kind);
  return rows.length ? rows[rows.length - 1] : null;
}

function paint() {
  const m = logDevice("status");
  clear();
  const loaded = createJournal(deviceAdapter()).read();
  const lang = code();
  if (!loaded.ok) {
    stack(m, t("status", lang), [
      { label: t("corrupt", lang), color: 0xc4a35a },
      { label: t("back", lang), name: "sens-back", action: () => back() },
    ]);
    return;
  }
  const gnss = latest(loaded.entries, "GNSS");
  const hr = latest(loaded.entries, "HR");
  const battery = latest(loaded.entries, "GNSS");
  const gnssLine = !gnss ? t("noSamples", lang) : (gnss.gpsStatus === "A" ? t("fix", lang) : t("noFix", lang));
  const hrLine = hr && hr.hrBpm != null ? t("hrPresent", lang) + " " + hr.hrBpm : t("hrUnavailable", lang);
  const batteryLine = battery && battery.batteryPercent != null ? "BAT " + battery.batteryPercent + "%" : t("batteryUnavailable", lang);
  const coord = gnss && gnss.lat != null && gnss.lon != null ? gnss.lat.toFixed(5) + " " + gnss.lon.toFixed(5) : t("noFix", lang);
  stack(m, t("status", lang), [
    { label: gnssLine, color: 0xc4a35a },
    { label: coord },
    { label: hrLine },
    { label: t("distanceUnresolved", lang) },
    { label: batteryLine },
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
