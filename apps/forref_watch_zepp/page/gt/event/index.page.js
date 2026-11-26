import { push, back } from "@zos/router";
import { logDevice, bindBack, clear, paintBase, textAt, button } from "../../../utils/chrome";
import { layoutEvent } from "../../../utils/geometry";
import { t, showTeam } from "../../../utils/text";
import { state } from "../../../utils/state";
import { TEXT_WARNING } from "../../../utils/theme";

function pick(name) {
  state().event = name;
  state().player = "";
  console.log("FORREF_CONTEXT team=" + state().team + " event=" + name + " player=");
  if (name === "GOAL") {
    state().goalIntentId = "";
    state().goalRecordId = "";
    state().goalNote = "";
    push({ url: "page/gt/review/index.page" });
    return;
  }
  push({ url: "page/gt/player/index.page" });
}

Page({
  onInit(params) {
    let data = params;
    if (typeof params === "string") {
      try {
        data = JSON.parse(params);
      } catch (err) {
        data = {};
      }
    }
    if (data && data.team) {
      state().team = data.team;
    }
    console.log("FORREF_LIFE event onInit team=" + state().team);
  },
  build() {
    const m = logDevice("event");
    bindBack(false);
    clear();
    paintBase(m);
    const lay = layoutEvent(m);
    textAt(lay.yellow.x, lay.titleY, lay.red.x + lay.red.w - lay.yellow.x, 32, showTeam(state().team) + " · " + t("notRecorded"), 16, TEXT_WARNING);
    button(lay.yellow.x, lay.yellow.y, lay.yellow.w, lay.yellow.h, t("yellow"), () => pick("YELLOW"), "yellow", "event-yellow", m);
    button(lay.red.x, lay.red.y, lay.red.w, lay.red.h, t("red"), () => pick("RED"), "red", "event-red", m);
    button(lay.goal.x, lay.goal.y, lay.goal.w, lay.goal.h, t("goal"), () => pick("GOAL"), "neutral", "event-goal", m);
    button(lay.sub.x, lay.sub.y, lay.sub.w, lay.sub.h, t("sub"), () => pick("SUB"), "neutral", "event-sub", m);
    button(lay.back.x, lay.back.y, lay.back.w, lay.back.h, t("back"), () => back(), "navigation", "event-back", m);
  },
  onDestroy() {
    console.log("FORREF_LIFE event onDestroy");
  },
});
