import { back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";
import { state } from "../../../utils/state";
import { TEXT_SECONDARY, TEXT_WARNING } from "../../../utils/theme";

function choose(mode) {
  state().display = mode;
  console.log("FORREF_DISPLAY " + mode + " via=back");
  back();
}

Page({
  build() {
    const m = logDevice("display");
    bindBack(false);
    const current = state().display === "C" ? "C" : "A";
    stack(m, t("displayTitle"), [
      { label: t("notProduct"), color: TEXT_WARNING },
      { label: t("memoryOnly") + " · " + current, color: TEXT_SECONDARY },
      { label: t("liveA"), action: () => choose("A"), fill: current === "A" ? "selected" : "navigation", name: "display-a" },
      { label: t("liveC"), action: () => choose("C"), fill: current === "C" ? "selected" : "navigation", name: "display-c" },
      { label: t("back"), action: () => back(), name: "display-back" },
    ]);
  },
});
