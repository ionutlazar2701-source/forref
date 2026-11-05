import { back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";

Page({
  build() {
    const m = logDevice("train-done");
    bindBack(false);
    stack(m, t("trainDone"), [
      { label: t("trainDoneBody") },
      { label: t("back"), action: () => back() },
    ]);
  },
});