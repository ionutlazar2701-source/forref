import * as hmUI from "@zos/ui";
import { getDeviceInfo, SCREEN_SHAPE_ROUND } from "@zos/device";
import { onKey, KEY_BACK, KEY_EVENT_CLICK } from "@zos/interaction";
import { back } from "@zos/router";
import { SQUARE_STATUS_BAR, SAFE_MARGIN, inside, layoutStack } from "./geometry";
import { localeChoice } from "./text";

const shellOwned = [];
const digitOwned = [];

function drop(list) {
  while (list.length) {
    hmUI.deleteWidget(list.pop());
  }
}

export function metrics() {
  const info = getDeviceInfo();
  const round = info.screenShape === SCREEN_SHAPE_ROUND;
  const pad = Math.round(info.width * (round ? 0.2 : 0.06));
  return {
    width: info.width,
    height: info.height,
    screenShape: info.screenShape,
    deviceName: info.deviceName,
    keyNumber: info.keyNumber,
    keyType: info.keyType,
    deviceSource: info.deviceSource,
    round: round,
    pad: pad,
    contentW: info.width - pad * 2,
    originY: round ? 0 : SQUARE_STATUS_BAR,
    safeMargin: SAFE_MARGIN,
    statusBar: round ? 0 : SQUARE_STATUS_BAR,
    shapeName: round ? "ROUND" : "RECT",
  };
}

export function logDevice(pageName) {
  const m = metrics();
  console.log(
    "FORREF_DEVICE page=" +
      pageName +
      " width=" +
      m.width +
      " height=" +
      m.height +
      " shape=" +
      m.shapeName +
      " screenShape=" +
      m.screenShape +
      " keyNumber=" +
      m.keyNumber +
      " keyType=" +
      m.keyType +
      " deviceSource=" +
      m.deviceSource +
      " deviceName=" +
      m.deviceName +
      " statusBar=" +
      m.statusBar +
      " safeMargin=" +
      m.safeMargin
  );
  const loc = localeChoice();
  console.log(
    "FORREF_LOCALE page=" +
      pageName +
      " code=" +
      loc.code +
      " lang=" +
      loc.lang +
      " reason=" +
      loc.reason
  );
  return m;
}

export function clear() {
  drop(digitOwned);
  drop(shellOwned);
}

export function clearDigits() {
  drop(digitOwned);
}

export function paintBase(m) {
  shellOwned.push(
    hmUI.createWidget(hmUI.widget.FILL_RECT, {
      x: 0,
      y: 0,
      w: m.width,
      h: m.height,
      color: 0x071d33,
    })
  );
}

export function textAt(x, y, w, h, value, size, color, digits) {
  const node = hmUI.createWidget(hmUI.widget.TEXT, {
    x: x,
    y: y,
    w: w,
    h: h,
    color: color || 0xffffff,
    text: value,
    text_size: size,
    align_h: hmUI.align.CENTER_H,
    align_v: hmUI.align.CENTER_V,
    text_style: hmUI.text_style.WRAP,
  });
  (digits === true ? digitOwned : shellOwned).push(node);
  return node;
}

export function text(m, value, y, h, size, color) {
  return textAt(m.pad, y, m.contentW, h, value, size, color);
}

export function button(x, y, w, h, label, onClick, fill, name, info) {
  const fit = info ? (inside(info, x, y, w, h) ? 1 : 0) : -1;
  if (name) {
    console.log(
      "FORREF_HIT name=" + name + " x=" + x + " y=" + y + " w=" + w + " h=" + h + " fit=" + fit
    );
  }
  const node = hmUI.createWidget(hmUI.widget.BUTTON, {
    x: x,
    y: y,
    w: w,
    h: h,
    radius: 14,
    normal_color: fill || 0x0b2d5b,
    press_color: 0x3fc3be,
    color: 0xffffff,
    text: label,
    text_size: Math.min(
      26,
      Math.max(14, Math.round(h * 0.3)),
      Math.max(14, Math.floor((w - 16) / Math.max(String(label).length, 1) / 0.62))
    ),
    click_func: onClick,
  });
  shellOwned.push(node);
  return node;
}

export function fullButton(m, label, y, h, onClick, fill) {
  return button(m.pad, y, m.contentW, h, label, onClick, fill);
}

export function bindBack(isRoot) {
  onKey({
    callback: (key, event) => {
      if (key === KEY_BACK && event === KEY_EVENT_CLICK && !isRoot) {
        back();
        return true;
      }
      return false;
    },
  });
}

export function stack(m, title, rows) {
  paintBase(m);
  const laid = layoutStack(m, rows.length);
  const guide = laid.rows[0] || { x: m.pad, w: m.contentW };
  textAt(guide.x, laid.titleY, guide.w, laid.titleH, title, Math.round(m.width * 0.045), 0x3fc3be);
  rows.forEach((row, index) => {
    const slot = laid.rows[index];
    if (!slot) {
      return;
    }
    if (row.action) {
      button(slot.x, slot.y, slot.w, slot.h, row.label, row.action, row.fill, row.name || "stack-" + index, m);
    } else {
      textAt(slot.x, slot.y, slot.w, slot.h, row.label, Math.round(m.width * 0.038), row.color || 0xffffff);
    }
  });
}
