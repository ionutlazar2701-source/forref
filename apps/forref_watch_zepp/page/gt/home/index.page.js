import { push } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t, language } from "../../../utils/text";

Page({
  onInit() {
    console.log("FORREF_PAGE home language=" + language());
  },
  build() {
    const m = logDevice("home");
    bindBack(true);
    stack(m, t("app"), [
      {
        label: m.width + "×" + m.height + " " + m.shapeName + " src " + m.deviceSource,
      },
      { label: "keys " + m.keyNumber + " " + m.keyType, color: 0x9bb0c7 },
      { label: t("officiate"), action: () => push({ url: "page/gt/select/index.page" }) },
      { label: t("train"), action: () => push({ url: "page/gt/train/index.page" }) },
      { label: t("settings"), action: () => push({ url: "page/gt/settings/index.page" }) },
    ]);
  },
});
