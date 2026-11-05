import { back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";

Page({
  build() {
    const m = logDevice("train-live");
    bindBack(false);
    stack(m, t("trainLive"), [
      { label: t("trainLiveBody") },
      { label: t("back"), action: () => back() },
    ]);
  },
});
