import { push, back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t, showTeam, showEvent } from "../../../utils/text";
import { state } from "../../../utils/state";

function pick(name) {
  state().player = name;
  push({ url: "page/gt/review/index.page" });
}

Page({
  build() {
    const m = logDevice("player");
    bindBack(false);
    stack(m, t("player"), [
      { label: showTeam(state().team) + " · " + showEvent(state().event), color: 0x9bb0c7 },
      { label: t("p9"), action: () => pick("PLAYER 9") },
      { label: t("p4"), action: () => pick("PLAYER 4") },
      { label: t("unknown"), action: () => pick("UNKNOWN") },
      { label: t("back"), action: () => back() },
    ]);
  },
});
