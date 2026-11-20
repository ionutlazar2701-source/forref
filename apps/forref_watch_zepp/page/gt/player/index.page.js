import { push, back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t, showTeam, showEvent } from "../../../utils/text";
import { state } from "../../../utils/state";
import { TEXT_SECONDARY } from "../../../utils/theme";

function pick(name) {
  state().player = name;
  push({ url: "page/gt/review/index.page" });
}

Page({
  onInit() {
    console.log("FORREF_LIFE player onInit event=" + state().event);
  },
  build() {
    const m = logDevice("player");
    bindBack(false);
    stack(m, t("player"), [
      { label: showTeam(state().team) + " · " + showEvent(state().event), color: TEXT_SECONDARY },
      { label: t("p9"), action: () => pick("PLAYER 9") },
      { label: t("p4"), action: () => pick("PLAYER 4") },
      { label: t("unknown"), action: () => pick("UNKNOWN") },
      { label: t("back"), action: () => back() },
    ]);
  },
  onDestroy() {
    console.log("FORREF_LIFE player onDestroy");
  },
});
