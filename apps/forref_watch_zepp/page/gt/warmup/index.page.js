import { back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";

Page({
  build() {
    const m = logDevice("warmup");
    bindBack(false);
    stack(m, t("warmup"), [
      { label: t("warmupBody") },
      { label: t("clockStopped"), color: 0xc4a35a },
      { label: t("back"), action: () => back() },
    ]);
  },
});
