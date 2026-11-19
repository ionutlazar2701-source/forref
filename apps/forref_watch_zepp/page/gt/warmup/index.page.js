import { back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";
import { TEXT_WARNING } from "../../../utils/theme";

Page({
  build() {
    const m = logDevice("warmup");
    bindBack(false);
    stack(m, t("warmup"), [
      { label: t("warmupBody") },
      { label: t("clockStopped"), color: TEXT_WARNING },
      { label: t("back"), action: () => back() },
    ]);
  },
});
