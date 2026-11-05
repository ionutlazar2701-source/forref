import { push, back } from "@zos/router";
import { logDevice, bindBack, clear, paintBase, textAt, button } from "../../../utils/chrome";
import { layoutLive } from "../../../utils/geometry";
import { t } from "../../../utils/text";
import { state } from "../../../utils/state";

function openTeam(team) {
  state().team = team;
  state().event = "";
  state().player = "";
  console.log("FORREF_CONTEXT team=" + team + " event= player=");
  push({ url: "page/gt/event/index.page", params: { team: team } });
}

function paint() {
  const m = logDevice("live");
  clear();
  const mode = state().display === "C" ? "C" : "A";
  console.log("FORREF_LIFE live build display=" + mode);
  const lay = layoutLive(m, mode);
  paintBase(m);
  const scoreHome = "1";
  const scoreAway = "0";
  const spanX = lay.home.x;
  const spanW = lay.away.x + lay.away.w - lay.home.x;
  textAt(spanX, lay.phaseY, spanW, 28, t("phase") + "  DEMO", Math.round(m.width * 0.04), 0x9bb0c7);
  textAt(spanX, lay.timeY, spanW, 40, t("time"), Math.round(m.width * 0.08), 0xffffff);
  button(lay.home.x, lay.home.y, lay.home.w, lay.home.h, t("home") + "  " + scoreHome, () => openTeam("HOME"), 0x0e3a55, "live-home", m);
  button(lay.away.x, lay.away.y, lay.away.w, lay.away.h, t("away") + "  " + scoreAway, () => openTeam("AWAY"), 0x0e3a55, "live-away", m);
  button(lay.display.x, lay.display.y, lay.display.w, lay.display.h, t("display"), () => push({ url: "page/gt/display/index.page" }), 0x0b2d5b, "live-display", m);
  button(lay.back.x, lay.back.y, lay.back.w, lay.back.h, t("back"), () => back(), 0x0b2d5b, "live-back", m);
}

Page({
  onInit() {
    console.log("FORREF_LIFE live onInit");
  },
  build() {
    bindBack(false);
    paint();
  },
  onDestroy() {
    console.log("FORREF_LIFE live onDestroy");
  },
});
