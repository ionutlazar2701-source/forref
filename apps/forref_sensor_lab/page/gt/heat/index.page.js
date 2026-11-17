import { back } from "@zos/router";
import { getLanguage } from "@zos/settings";
import { bindBack, clear, logDevice, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";
import { latestSessionId } from "../../../lib/analytics";
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
  const m = logDevice("heat");
  clear();
  const lang = code();
  const loaded = createJournal(deviceAdapter()).read();
  const sessionId = loaded.ok ? latestSessionId(loaded.entries) : "";
  const fixes = loaded.ok ? loaded.entries.filter((entry) => entry.sessionId === sessionId && entry.kind === "GNSS" && entry.gpsStatus === "A" && entry.lat != null) : [];
  const line = !loaded.ok ? t("corrupt", lang) : (fixes.length === 0 ? t("heatUnavailable", lang) : t("noCalibration", lang));
  stack(m, t("heat", lang), [
    { label: line, color: 0xc4a35a },
    { label: t("notMatch", lang) },
    { label: t("experimental", lang) },
    { label: t("back", lang), name: "sens-back", action: () => back() },
  ]);
}

Page({
  build() {
    bindBack(false);
    paint();
  },
});
