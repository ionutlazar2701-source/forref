import * as hmUI from "@zos/ui";
import { getDeviceInfo, SCREEN_SHAPE_ROUND } from "@zos/device";
import { queryPermission, requestPermission } from "@zos/app";
import { getSportData } from "@zos/app-access";
import { getLanguage } from "@zos/settings";
import { clearTimeout, setTimeout } from "@zos/timer";
import { layoutProbe } from "../../../lib/layout";
import { lines, t } from "../../../utils/text";
import {
  WORKOUT_PERMISSION,
  applyPermissionCallback,
  applyPermissionQuery,
  applyPermissionRequest,
  applySportResult,
  beginPending,
  initialProbe,
  markStillPending,
  openSportRead,
} from "../../../../forref_sensor_lab/lib/native_elapsed";

const owned = [];
let texts = {};
let state = initialProbe();
let waitId = null;
let metrics = { width: 390, height: 450, round: false, screenShape: 0 };

function code() {
  try {
    return getLanguage();
  } catch (err) {
    return -1;
  }
}

function clearWait() {
  if (waitId != null) {
    clearTimeout(waitId);
    waitId = null;
  }
}

function logState() {
  const shown = state.durationText || "-";
  const payload = state.raw ? String(state.raw).slice(0, 80) : "-";
  const call = state.accepted === true ? "1" : state.accepted === false ? "0" : "-";
  console.log(
    "DUR001 perm=" + (state.permission == null ? "-" : state.permission) +
    " ask=" + (state.requestImmediate == null ? "-" : state.requestImmediate) +
    "/" + (state.requestList == null ? "-" : state.requestList) +
    " call=" + call +
    " code=" + (state.code == null ? "-" : state.code) +
    " show=" + shown +
    " raw=" + payload +
    " st=" + state.status +
    " reason=" + state.reason
  );
}

function paint() {
  const rows = lines(state, code());
  for (let i = 0; i < rows.length; i += 1) {
    const widget = texts[rows[i].name];
    if (!widget || !widget.setProperty) {
      continue;
    }
    try {
      widget.setProperty(hmUI.prop.TEXT, rows[i].text);
    } catch (err) {
      console.log("DUR001 ui=TEXT_FAILED");
    }
  }
  logState();
}

function ask() {
  let immediate = null;
  try {
    immediate = requestPermission({
      permissions: [WORKOUT_PERMISSION],
      callback: function (result) {
        state = applyPermissionCallback(state, result);
        paint();
      },
    });
  } catch (err) {
    state = applyPermissionRequest(state, null);
    paint();
    return;
  }
  state = applyPermissionRequest(state, immediate);
  paint();
}

function read() {
  clearWait();
  const opened = openSportRead(function (options, callback) {
    return getSportData(options, callback);
  }, function (reading) {
    clearWait();
    state = applySportResult(state, reading);
    paint();
  });
  if (opened.phase === "PENDING") {
    state = beginPending(state, true);
    paint();
    waitId = setTimeout(function () {
      state = markStillPending(state);
      paint();
    }, 10000);
  }
}

function mount() {
  while (owned.length) {
    owned.pop();
  }
  texts = {};
  const laid = layoutProbe(metrics, 8);
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
    { name: "request", text: t("request", code()), action: ask },
    { name: "read", text: t("read", code()), action: read },
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
      align_h: hmUI.align.CENTER_H, align_v: hmUI.align.CENTER_V, text_style: hmUI.text_style.WRAP,
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
      console.log("DUR001 device source=" + info.deviceSource + " name=" + info.deviceName);
    } catch (err) {
      console.log("DUR001 device=fail");
    }
  },
  build() {
    try {
      state = applyPermissionQuery(initialProbe(), queryPermission({ permissions: [WORKOUT_PERMISSION] }));
    } catch (err) {
      state = applyPermissionQuery(initialProbe(), null);
    }
    mount();
    paint();
  },
  onDestroy() {
    clearWait();
  },
});
