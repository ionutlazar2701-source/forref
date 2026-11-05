import { back } from "@zos/router";
import { logDevice, bindBack, clear, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";
import { state } from "../../../utils/state";

let step = 1;

function allocation() {
  const s = state();
  if (s.tossChoice !== "KICK") {
    return t("directionOpen");
  }
  if (s.tossWinner === "HOME") {
    return "1H HOME · 2H AWAY";
  }
  if (s.tossWinner === "AWAY") {
    return "1H AWAY · 2H HOME";
  }
  return t("directionOpen");
}

function paint() {
  const m = logDevice("toss");
  clear();
  if (step === 1) {
    stack(m, t("tossQ"), [
      {
        label: t("home"),
        action: () => {
          state().tossWinner = "HOME";
          step = 2;
          paint();
        },
      },
      {
        label: t("away"),
        action: () => {
          state().tossWinner = "AWAY";
          step = 2;
          paint();
        },
      },
      { label: t("back"), action: () => back() },
    ]);
    return;
  }
  if (step === 2) {
    stack(m, t("choice"), [
      { label: state().tossWinner, color: 0x9bb0c7 },
      {
        label: t("kick"),
        action: () => {
          state().tossChoice = "KICK";
          step = 3;
          paint();
        },
      },
      {
        label: t("attack"),
        action: () => {
          state().tossChoice = "ATTACK";
          step = 3;
          paint();
        },
      },
      {
        label: t("back"),
        action: () => {
          step = 1;
          paint();
        },
      },
    ]);
    return;
  }
  stack(m, t("review"), [
    { label: state().tossWinner + " · " + state().tossChoice },
    { label: allocation() },
    { label: t("notRecorded"), color: 0xc4a35a },
    { label: t("back"), action: () => back() },
  ]);
}

Page({
  onInit() {
    step = 1;
    state().tossWinner = "";
    state().tossChoice = "";
  },
  build() {
    bindBack(false);
    paint();
  },
});
