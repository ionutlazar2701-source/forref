import { push, back } from "@zos/router";
import { logDevice, bindBack, clear, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";
import { state } from "../../../utils/state";

function localeLabel() {
  const mode = state().localeTest || "";
  if (mode === "ro-RO") {
    return t("localeRo");
  }
  if (mode === "en-US") {
    return t("localeEn");
  }
  return t("localeOs");
}

function cycleLocale() {
  const mode = state().localeTest || "";
  state().localeTest = mode === "" ? "ro-RO" : mode === "ro-RO" ? "en-US" : "";
  console.log("FORREF_LOCALE_SET " + (state().localeTest || "OS"));
  paint();
}

function paint() {
  const m = logDevice("settings");
  clear();
  const mode = state().display === "C" ? "C" : "A";
  stack(m, t("settings"), [
    { label: t("tempDefault") + " " + mode, color: 0xc4a35a },
    { label: t("displayTitle"), action: () => push({ url: "page/gt/display/index.page" }), name: "settings-display" },
    { label: localeLabel(), action: () => cycleLocale(), name: "settings-locale" },
    { label: t("cautions"), action: () => push({ url: "page/gt/cautions/index.page" }), name: "settings-g1" },
    { label: t("neutral"), action: () => push({ url: "page/gt/neutral/index.page" }), name: "settings-g2" },
    { label: t("back"), action: () => back(), name: "settings-back" },
  ]);
}

Page({
  build() {
    bindBack(false);
    paint();
  },
});
