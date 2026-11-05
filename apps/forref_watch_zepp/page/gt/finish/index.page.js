import { back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";

Page({
  build() {
    const m = logDevice("finish");
    bindBack(false);
    stack(m, t("finish"), [
      { label: t("finishBody") },
      { label: t("back"), action: () => back() },
    ]);
  },
});
