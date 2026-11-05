import { push, back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";

Page({
  build() {
    const m = logDevice("hub");
    bindBack(false);
    stack(m, t("hub"), [
      { label: t("clockStopped"), color: 0xc4a35a },
      { label: t("coin"), action: () => push({ url: "page/gt/toss/index.page" }) },
      { label: t("warmup"), action: () => push({ url: "page/gt/warmup/index.page" }) },
      { label: t("incident"), action: () => push({ url: "page/gt/incident/index.page" }) },
      { label: t("prepare"), action: () => push({ url: "page/gt/ready/index.page" }) },
      { label: t("back"), action: () => back() },
    ]);
  },
});
