import { push } from "@zos/router";
import { logDevice, bindBack, clear, paintBase, textAt, zoneButton, rule } from "../../../utils/chrome";
import { layoutHome } from "../../../utils/geometry";
import { t, language } from "../../../utils/text";
import { ACCENT, TEXT_PRIMARY, TEXT_SECONDARY } from "../../../utils/theme";

function paintZone(m, lay, zone, lines, title, body, onClick, name) {
  zoneButton(zone.x, zone.y, zone.w, zone.h, onClick, name, m);
  textAt(lines.title.x, lines.title.y, lines.title.w, lines.title.h, title, lay.titleSize, TEXT_PRIMARY);
  textAt(lines.subtitle.x, lines.subtitle.y, lines.subtitle.w, lines.subtitle.h, body, lay.subtitleSize, TEXT_SECONDARY);
}

Page({
  onInit() {
    console.log("FORREF_PAGE home language=" + language());
  },
  build() {
    const m = logDevice("home");
    bindBack(true);
    clear();
    paintBase(m);
    const lay = layoutHome(m);
    paintZone(m, lay, lay.upper, lay.upperText, t("officiate"), t("officiateBody"), function () {
      push({ url: "page/gt/select/index.page" });
    }, "home-officiate");
    paintZone(m, lay, lay.middle, lay.middleText, t("train"), t("trainHint"), function () {
      push({ url: "page/gt/train/index.page" });
    }, "home-train");
    paintZone(m, lay, lay.lower, lay.lowerText, t("settings"), t("settingsBody"), function () {
      push({ url: "page/gt/settings/index.page" });
    }, "home-settings");
    rule(lay.divider.x, lay.divider.y, lay.divider.w, lay.divider.h, ACCENT);
    rule(lay.dividerLower.x, lay.dividerLower.y, lay.dividerLower.w, lay.dividerLower.h, ACCENT);
  },
});
