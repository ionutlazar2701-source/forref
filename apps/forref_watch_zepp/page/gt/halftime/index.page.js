import { back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";

Page({
  build() {
    const m = logDevice("halftime");
    bindBack(false);
    stack(m, t("halftime"), [
      { label: t("halftimeBody") },
      { label: t("back"), action: () => back() },
    ]);
  },
});
