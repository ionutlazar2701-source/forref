import { back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";
import { state } from "../../../utils/state";

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
      { label: t("notProduct"), color: 0xc4a35a },
      { label: t("memoryOnly") + " · " + current, color: 0x9bb0c7 },
      { label: t("liveA"), action: () => choose("A"), fill: current === "A" ? 0x0e5c58 : 0x0b2d5b, name: "display-a" },
      { label: t("liveC"), action: () => choose("C"), fill: current === "C" ? 0x0e5c58 : 0x0b2d5b, name: "display-c" },
      { label: t("back"), action: () => back(), name: "display-back" },
    ]);
  },
});
