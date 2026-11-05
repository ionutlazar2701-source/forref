import { back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";

Page({
  build() {
    const m = logDevice("incident");
    bindBack(false);
    stack(m, t("incident"), [
      { label: t("incidentBody") },
      { label: t("back"), action: () => back() },
    ]);
  },
});
