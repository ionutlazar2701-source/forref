import * as hmUI from "@zos/ui";
import { getDeviceInfo, SCREEN_SHAPE_ROUND } from "@zos/device";
import { onKey, KEY_BACK, KEY_EVENT_CLICK } from "@zos/interaction";
import { back } from "@zos/router";
import { layoutLab } from "../lib/layout";

const owned = [];

export function metrics() {
  const info = getDeviceInfo();
  const round = info.screenShape === SCREEN_SHAPE_ROUND;
  return {
    width: info.width,
    height: info.height,
    screenShape: info.screenShape,
    deviceName: info.deviceName,
    keyNumber: info.keyNumber,
    keyType: info.keyType,
    deviceSource: info.deviceSource,
    round: round,
  };
}

export function logDevice(pageName) {
  const m = metrics();
  console.log(
    "FORREF_SENS_DEVICE page=" + pageName +
    " width=" + m.width +
    " height=" + m.height +
    " shape=" + (m.round ? "ROUND" : "RECT") +
    " screenShape=" + m.screenShape +
    " deviceSource=" + m.deviceSource +
    " deviceName=" + m.deviceName
  );
  return m;
}

export function clear() {
  while (owned.length) {
    hmUI.deleteWidget(owned.pop());
  }
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
  owned.push(hmUI.createWidget(hmUI.widget.FILL_RECT, { x: 0, y: 0, w: m.width, h: m.height, color: 0x071d33 }));
  const laid = layoutLab(m, rows.length);
  const guide = laid.rows[0] || { x: 12, w: m.width - 24 };
  owned.push(hmUI.createWidget(hmUI.widget.TEXT, {
    x: guide.x, y: laid.titleY, w: guide.w, h: laid.titleH,
    color: 0x3fc3be, text: title, text_size: 22, align_h: hmUI.align.CENTER_H, align_v: hmUI.align.CENTER_V,
  }));
  rows.forEach((row, index) => {
    const slot = laid.rows[index];
    if (!slot) {
      return;
    }
    if (row.action) {
      console.log("FORREF_SENS_HIT name=" + (row.name || "row-" + index) + " x=" + slot.x + " y=" + slot.y + " w=" + slot.w + " h=" + slot.h);
      owned.push(hmUI.createWidget(hmUI.widget.BUTTON, {
        x: slot.x, y: slot.y, w: slot.w, h: slot.h, radius: 12,
        normal_color: row.fill || 0x0b2d5b, press_color: 0x3fc3be, color: 0xffffff,
        text: row.label, text_size: slot.h < 40 ? 14 : 18, click_func: row.action,
      }));
    } else {
      owned.push(hmUI.createWidget(hmUI.widget.TEXT, {
        x: slot.x, y: slot.y, w: slot.w, h: slot.h,
        color: row.color || 0xffffff, text: row.label, text_size: slot.h < 40 ? 14 : 16,
        align_h: hmUI.align.CENTER_H, align_v: hmUI.align.CENTER_V, text_style: hmUI.text_style.WRAP,
      }));
    }
  });
}

export function mountSession(m, title, rows) {
  clear();
  const laid = layoutLab(m, rows.length);
  const guide = laid.rows[0] || { x: 12, w: m.width - 24 };
  const texts = {};
  owned.push(hmUI.createWidget(hmUI.widget.FILL_RECT, { x: 0, y: 0, w: m.width, h: m.height, color: 0x071d33 }));
  owned.push(hmUI.createWidget(hmUI.widget.TEXT, {
    x: guide.x, y: laid.titleY, w: guide.w, h: laid.titleH,
    color: 0x3fc3be, text: title, text_size: 22, align_h: hmUI.align.CENTER_H, align_v: hmUI.align.CENTER_V,
  }));
  rows.forEach((row, index) => {
    const slot = laid.rows[index];
    if (!slot) {
      return;
    }
    if (row.action) {
      console.log("FORREF_SENS_V2 hit=" + (row.name || "row-" + index) + " d1=UNCERTIFIED");
      owned.push(hmUI.createWidget(hmUI.widget.BUTTON, {
        x: slot.x, y: slot.y, w: slot.w, h: slot.h, radius: 12,
        normal_color: 0x0b2d5b, press_color: 0x3fc3be, color: 0xffffff,
        text: row.label, text_size: slot.h < 40 ? 14 : 18, click_func: row.action,
      }));
      return;
    }
    const widget = hmUI.createWidget(hmUI.widget.TEXT, {
      x: slot.x, y: slot.y, w: slot.w, h: slot.h,
      color: row.color || 0xffffff, text: row.label, text_size: slot.h < 40 ? 14 : 16,
      align_h: hmUI.align.CENTER_H, align_v: hmUI.align.CENTER_V, text_style: hmUI.text_style.WRAP,
    });
    owned.push(widget);
    if (row.name) {
      texts[row.name] = widget;
    }
  });
  return {
    texts: texts,
    setText(name, value) {
      const widget = texts[name];
      try {
        if (widget && widget.setProperty && hmUI.prop && hmUI.prop.TEXT != null) {
          widget.setProperty(hmUI.prop.TEXT, value);
        }
      } catch (err) {
        console.log("FORREF_SENS_V2 ui=TEXT_FAILED d1=UNCERTIFIED");
      }
    },
  };
}
