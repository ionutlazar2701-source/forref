import { push, back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";

Page({
  build() {
    const m = logDevice("train");
    bindBack(false);
    stack(m, t("trainTitle"), [
      { label: t("trainBody") },
      { label: t("trainWarm"), action: () => push({ url: "page/gt/train-warm/index.page" }) },
      { label: t("trainLive"), action: () => push({ url: "page/gt/train-live/index.page" }) },
      { label: t("trainDone"), action: () => push({ url: "page/gt/train-done/index.page" }) },
      { label: t("back"), action: () => back() },
    ]);
  },
});
