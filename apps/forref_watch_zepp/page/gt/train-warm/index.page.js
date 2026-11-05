import { back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";

Page({
  build() {
    const m = logDevice("train-warm");
    bindBack(false);
    stack(m, t("trainWarm"), [
      { label: t("trainWarmBody") },
      { label: t("back"), action: () => back() },
    ]);
  },
});
