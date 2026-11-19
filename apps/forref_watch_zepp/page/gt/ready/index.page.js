import { push, back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";
import { TEXT_WARNING } from "../../../utils/theme";

Page({
  build() {
    const m = logDevice("ready");
    bindBack(false);
    stack(m, t("readyTitle"), [
      { label: t("readyBody"), color: TEXT_WARNING },
      { label: t("clockStopped") },
      { label: t("openLive"), action: () => push({ url: "page/gt/live/index.page" }), fill: "primary" },
      { label: t("back"), action: () => back() },
    ]);
  },
});
