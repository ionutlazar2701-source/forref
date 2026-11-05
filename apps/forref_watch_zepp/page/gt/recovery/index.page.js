import { back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";

Page({
  build() {
    const m = logDevice("recovery");
    bindBack(false);
    stack(m, t("recovery"), [
      { label: t("recoveryBody") },
      { label: t("back"), action: () => back() },
    ]);
  },
});
