import { push, back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";
import { TEXT_WARNING } from "../../../utils/theme";

Page({
  build() {
    const m = logDevice("select");
    bindBack(false);
    stack(m, t("select"), [
      { label: t("unverified"), color: TEXT_WARNING },
      {
        label: t("fixture") + "  " + t("when"),
        action: () => push({ url: "page/gt/hub/index.page" }),
        fill: "primary",
      },
      { label: t("back"), action: () => back() },
    ]);
  },
});
