import { back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";

Page({
  build() {
    const m = logDevice("cautions");
    bindBack(false);
    stack(m, t("cautions"), [
      { label: t("cautionsBody") },
      { label: t("back"), action: () => back() },
    ]);
  },
});
