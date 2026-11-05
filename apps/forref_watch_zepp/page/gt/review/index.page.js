import { back } from "@zos/router";
import { logDevice, bindBack, stack } from "../../../utils/chrome";
import { t, showTeam, showEvent, showPlayer } from "../../../utils/text";
import { state } from "../../../utils/state";

Page({
  build() {
    const m = logDevice("review");
    bindBack(false);
    const s = state();
    console.log("FORREF_CONTEXT team=" + s.team + " event=" + s.event + " player=" + s.player);
    stack(m, t("review"), [
      { label: showTeam(s.team) + " · " + showEvent(s.event) },
      { label: showPlayer(s.player) },
      { label: t("recordingOff"), color: 0xc4a35a },
      { label: t("back"), action: () => back() },
    ]);
  },
});
