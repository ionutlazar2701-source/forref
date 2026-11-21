import * as hmUI from "@zos/ui";
import { Time, Screen } from "@zos/sensor";
import { readFileSync, writeFileSync } from "@zos/fs";
import { setWakeUpRelaunch } from "@zos/display";
import { getDeviceInfo } from "@zos/device";
import { getLanguage } from "@zos/settings";
import { setInterval, clearInterval } from "@zos/timer";
import { fresh, transition, phoneTimeChanged, readClock, STATUS } from "../../../lib/chron004";
import { load, commit } from "../../../lib/dual_slot";
import { layoutChron } from "../../../lib/layout";
import { t } from "../../../utils/text";

const time = new Time();
const screen = new Screen();
const io = {
  read(path) {
    let value;
    try {
      value = readFileSync({ path: path, options: { encoding: "utf8" } });
    } catch (err) {
      console.log("CHRON004 READ_FAILED " + path);
      return "";
    }
    // Documented result is string, or undefined when the file cannot be read.
    if (typeof value !== "string") {
      return "";
    }
    return value;
  },
  write(path, data) {
    writeFileSync({
      path: path,
      data: data,
      options: { encoding: "utf8" },
    });
  },
};

let record = null;
let timer = null;
let visibleTicks = 0;
let metrics = { width: 390, height: 450 };
let textClock = null;
let textStatus = null;
let textDetail = null;
let textDiagnostic = null;
let buttonPrimary = null;
let buttonSecondary = null;

function now() {
  return time.getTime();
}

function lang() {
  try {
    return getLanguage();
  } catch (err) {
    return -1;
  }
}

function log(message) {
  console.log("CHRON004 " + message);
}

function update(recordValue) {
  const committed = commit(io, recordValue);
  if (committed.ok) {
    record = recordValue;
  } else {
    log("PERSIST_FAILURE " + committed.reason);
  }
  return committed.ok;
}

function boot() {
  const stored = load(io);
  if (stored.ok) {
    record = stored.record;
  } else if (stored.reason === "EMPTY") {
    record = fresh();
  } else {
    record = null;
  }
  log("BOOT restore=" + stored.reason + " seq=" + (record ? record.seq : "-"));
}

function action(event) {
  if (!record) {
    return;
  }
  const result = transition(record, event, now());
  if (!result.ok) {
    log("REJECT " + result.reason);
    return;
  }
  update(result.record);
  paint();
}

function primary() {
  if (!record) {
    return;
  }
  if (record.phase === STATUS.READY) {
    action("KICK_OFF");
  } else if (record.phase === STATUS.PAUSED) {
    action("RESUME");
  } else if (record.phase === STATUS.HALF_TIME) {
    action("START_SECOND_HALF");
  }
}

function secondary() {
  if (!record) {
    return;
  }
  if (record.phase === STATUS.RUNNING) {
    action("PAUSE");
  } else if (record.phase === STATUS.PAUSED && record.half === 1) {
    action("END_FIRST_HALF");
  } else if (record.phase === STATUS.PAUSED && record.half === 2) {
    action("FULL_TIME");
  }
}

function buttonLabels() {
  const code = lang();
  if (!record) {
    return { primary: t("idle", code), secondary: t("idle", code) };
  }
  if (record.phase === STATUS.READY) {
    return { primary: t("start", code), secondary: t("idle", code) };
  }
  if (record.phase === STATUS.RUNNING) {
    return { primary: t("idle", code), secondary: t("pause", code) };
  }
  if (record.phase === STATUS.PAUSED && record.half === 1) {
    return { primary: t("resume", code), secondary: t("endHalf", code) };
  }
  if (record.phase === STATUS.PAUSED && record.half === 2) {
    return { primary: t("resume", code), secondary: t("fullTime", code) };
  }
  if (record.phase === STATUS.HALF_TIME) {
    return { primary: t("secondHalf", code), secondary: t("idle", code) };
  }
  return { primary: t("idle", code), secondary: t("idle", code) };
}

function paint() {
  if (!textClock) {
    return;
  }
  const reading = record
    ? readClock(record, now())
    : { status: "TIME_UNKNOWN", display: null, reason: "NO_RECORD" };
  const label = reading.display || "TIME UNKNOWN";
  const labels = buttonLabels();
  textClock.setProperty(hmUI.prop.TEXT, label);
  textStatus.setProperty(hmUI.prop.TEXT, (record ? record.phase : "NO_RECORD") + " | " + reading.status);
  textDetail.setProperty(hmUI.prop.TEXT, reading.reason || "");
  textDiagnostic.setProperty(
    hmUI.prop.TEXT,
    "ticks=" + visibleTicks + " seq=" + (record ? record.seq : "-")
  );
  if (buttonPrimary) {
    buttonPrimary.setProperty(hmUI.prop.TEXT, labels.primary);
  }
  if (buttonSecondary) {
    buttonSecondary.setProperty(hmUI.prop.TEXT, labels.secondary);
  }
}

function textWidget(box, size, value) {
  return hmUI.createWidget(hmUI.widget.TEXT, {
    x: box.x,
    y: box.y,
    w: box.w,
    h: box.h,
    color: 0xffffff,
    text_size: size,
    text: value,
    align_h: hmUI.align.CENTER_H,
    align_v: hmUI.align.CENTER_V,
    text_style: hmUI.text_style.WRAP,
  });
}

Page({
  onInit() {
    try {
      const info = getDeviceInfo();
      if (info && info.width > 0 && info.height > 0) {
        metrics = { width: info.width, height: info.height };
      }
      log("DEVICE source=" + info.deviceSource + " name=" + info.deviceName + " " + metrics.width + "x" + metrics.height);
    } catch (err) {
      log("DEVICE_UNAVAILABLE");
    }
    try {
      setWakeUpRelaunch({ relaunch: true });
    } catch (err) {
      log("RELAUNCH_UNAVAILABLE");
    }
    boot();
    try {
      time.onPhoneTimeSetting(function () {
        if (!record || record.phase !== STATUS.RUNNING) {
          log("PHONE_TIME_SETTING ignored phase=" + (record ? record.phase : "-"));
          return;
        }
        const changed = phoneTimeChanged(record);
        if (changed.ok) {
          update(changed.record);
        }
        log("PHONE_TIME_SETTING -> TIME_UNKNOWN utc=" + now());
        paint();
      });
    } catch (err) {
      log("PHONE_TIME_LISTENER_FAILED");
    }
    try {
      screen.onChange(function (status) {
        const reading = record ? readClock(record, now()) : null;
        log(
          "SCREEN status=" + status +
          " utc=" + now() +
          " display=" + (reading ? reading.display : "-") +
          " trust=" + (reading ? reading.status : "-") +
          " ticks=" + visibleTicks
        );
      });
    } catch (err) {
      log("SCREEN_LISTENER_FAILED");
    }
  },
  build() {
    const laid = layoutChron(metrics.width, metrics.height);
    hmUI.createWidget(hmUI.widget.FILL_RECT, {
      x: laid.background.x,
      y: laid.background.y,
      w: laid.background.w,
      h: laid.background.h,
      color: 0x000000,
    });
    textWidget(laid.title, 18, t("title", lang()));
    textClock = textWidget(laid.clock, 36, "--:--");
    textStatus = textWidget(laid.status, 16, "--");
    textDetail = textWidget(laid.detail, 14, t("notMatch", lang()));
    textDiagnostic = textWidget(laid.diagnostic, 14, "ticks=0");
    buttonPrimary = hmUI.createWidget(hmUI.widget.BUTTON, {
      x: laid.primary.x,
      y: laid.primary.y,
      w: laid.primary.w,
      h: laid.primary.h,
      radius: 10,
      text: t("start", lang()),
      text_size: 16,
      color: 0xffffff,
      normal_color: 0x202020,
      press_color: 0x404040,
      click_func: primary,
    });
    buttonSecondary = hmUI.createWidget(hmUI.widget.BUTTON, {
      x: laid.secondary.x,
      y: laid.secondary.y,
      w: laid.secondary.w,
      h: laid.secondary.h,
      radius: 10,
      text: t("pause", lang()),
      text_size: 16,
      color: 0xffffff,
      normal_color: 0x202020,
      press_color: 0x404040,
      click_func: secondary,
    });
    timer = setInterval(function () {
      visibleTicks += 1;
      paint();
    }, 1000);
    paint();
  },
  onDestroy() {
    if (timer !== null) {
      clearInterval(timer);
      timer = null;
    }
    log("EXIT uiTicks=" + visibleTicks);
  },
});
