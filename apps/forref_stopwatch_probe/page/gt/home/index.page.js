import * as hmUI from "@zos/ui";
import { getDeviceInfo, SCREEN_SHAPE_ROUND } from "@zos/device";
import { getLanguage } from "@zos/settings";
import { checkSystemApp, launchApp, SYSTEM_APP_STOPWATCH } from "@zos/router";
import { layoutProbe } from "../../../lib/layout";
import { lines, t } from "../../../utils/text";
import { applyCall, classifyCall, initialScreen } from "../../../lib/native_stopwatch";

const owned = [];
let texts = {};
let state = initialScreen();
let metrics = { width: 390, height: 450, round: false, screenShape: 0 };

function code() {
  try {
    return getLanguage();
  } catch (err) {
    return -1;
  }
}

function logState() {
  console.log(
    "SW001 read=" + state.read +
    " control=" + state.control +
    " binding=" + state.binding +
    " check=" + state.check +
    " open=" + state.open +
    " st=" + state.status
  );
}

function paint() {
  const rows = lines(state, code());
  for (let i = 0; i < rows.length; i += 1) {
    const item = texts[rows[i].name];
    if (!item || !item.setProperty) {
      continue;
    }
    try {
      item.setProperty(hmUI.prop.TEXT, rows[i].text);
    } catch (err) {
      console.log("SW001 ui=TEXT_FAILED");
    }
  }
  logState();
}

function invoke(name, fn) {
  let returned;
  let threw = false;
  try {
    returned = fn();
  } catch (err) {
    threw = true;
  }
  return classifyCall(name, returned, threw);
}

function openStopwatch() {
  state = applyCall(state, "open", invoke("launchApp", function () {
    return launchApp({
      appId: SYSTEM_APP_STOPWATCH,
      url: "",
      native: true,
    });
  }));
  paint();
}

function mount() {
  while (owned.length) {
    owned.pop();
  }
  texts = {};
  const laid = layoutProbe(metrics, 7);
  const guide = laid.rows[0];
  owned.push(hmUI.createWidget(hmUI.widget.FILL_RECT, {
    x: 0, y: 0, w: metrics.width, h: metrics.height, color: 0x000000,
  }));
  owned.push(hmUI.createWidget(hmUI.widget.TEXT, {
    x: guide.x, y: laid.titleY, w: guide.w, h: laid.titleH,
    color: 0xffffff, text: t("title", code()), text_size: 22,
    align_h: hmUI.align.CENTER_H, align_v: hmUI.align.CENTER_V,
  }));
  const rows = lines(state, code()).concat([
    { name: "launch", text: t("launch", code()), action: openStopwatch },
  ]);
  for (let i = 0; i < rows.length; i += 1) {
    const slot = laid.rows[i];
    const row = rows[i];
    if (!slot || !row) {
      continue;
    }
    if (row.action) {
      owned.push(hmUI.createWidget(hmUI.widget.BUTTON, {
        x: slot.x, y: slot.y, w: slot.w, h: slot.h, radius: 12,
        normal_color: 0x1a1a1a, press_color: 0x333333, color: 0xffffff,
        text: row.text, text_size: 16, click_func: row.action,
      }));
      continue;
    }
    const item = hmUI.createWidget(hmUI.widget.TEXT, {
      x: slot.x, y: slot.y, w: slot.w, h: slot.h,
      color: 0xffffff, text: row.text, text_size: 18,
      align_h: hmUI.align.CENTER_H, align_v: hmUI.align.CENTER_V,
      text_style: hmUI.text_style.WRAP,
    });
    owned.push(item);
    texts[row.name] = item;
  }
}

Page({
  onInit() {
    try {
      const info = getDeviceInfo();
      metrics = {
        width: info.width,
        height: info.height,
        round: info.screenShape === SCREEN_SHAPE_ROUND,
        screenShape: info.screenShape,
      };
      console.log("SW001 device source=" + info.deviceSource + " name=" + info.deviceName);
    } catch (err) {
      console.log("SW001 device=fail");
    }
  },
  build() {
    state = applyCall(initialScreen(), "check", invoke("checkSystemApp", function () {
      return checkSystemApp({ appId: SYSTEM_APP_STOPWATCH });
    }));
    mount();
    paint();
  },
});
