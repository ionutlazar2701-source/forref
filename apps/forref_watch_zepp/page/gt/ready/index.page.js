import { push, back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";

Page({
  build() {
    const m = logDevice("ready");
    bindBack(false);
    stack(m, t("readyTitle"), [
      { label: t("readyBody"), color: 0xc4a35a },
      { label: t("clockStopped") },
      { label: t("openLive"), action: () => push({ url: "page/gt/live/index.page" }) },
      { label: t("back"), action: () => back() },
    ]);
  },
});
