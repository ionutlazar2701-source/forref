import { push, back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";

Page({
  build() {
    const m = logDevice("select");
    bindBack(false);
    stack(m, t("select"), [
      { label: t("unverified"), color: 0xc4a35a },
      {
        label: t("fixture") + "  " + t("when"),
        action: () => push({ url: "page/gt/hub/index.page" }),
      },
      { label: t("back"), action: () => back() },
    ]);
  },
});
