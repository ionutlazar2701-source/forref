import { push, back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";

Page({
  build() {
    const m = logDevice("neutral");
    bindBack(false);
    stack(m, t("neutral"), [
      { label: t("neutralBody") },
      { label: t("halftime"), action: () => push({ url: "page/gt/halftime/index.page" }) },
      { label: t("recovery"), action: () => push({ url: "page/gt/recovery/index.page" }) },
      { label: t("finish"), action: () => push({ url: "page/gt/finish/index.page" }) },
      { label: t("back"), action: () => back() },
    ]);
  },
});
