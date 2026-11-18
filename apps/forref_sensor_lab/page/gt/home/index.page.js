import { push } from "@zos/router";
import { Geolocation, HeartRate, Battery, checkSensor } from "@zos/sensor";
import { getLanguage } from "@zos/settings";
import { clearInterval, clearTimeout, setInterval, setTimeout } from "@zos/timer";
import { bindBack, logDevice, mountSession } from "../../../utils/chrome";
import { gpsLabel, hrLabel, t } from "../../../utils/text";
import { createSensorHost } from "../../../lib/host";
import { chunkAdapter } from "../../../utils/device_fs";

const clock = {
  origin: Date.now(),
  elapsed() {
    return Date.now() - this.origin;
  },
  utc() {
    return Date.now();
  },
};

const host = createSensorHost({
  Geolocation: Geolocation,
  HeartRate: HeartRate,
  Battery: Battery,
  checkSensor: checkSensor,
}, chunkAdapter(), clock, {
  set(fn, ms) {
    return setTimeout(fn, ms);
  },
  clear(id) {
    clearTimeout(id);
  },
});

let ui = null;
let paintTimer = null;
let batteryTimer = null;
let lastPaint = 0;

function code() {
  try {
    return getLanguage();
  } catch (err) {
    return -1;
  }
}

function distanceLine(view, lang) {
  if (view.storageFull) {
    return t("storageFull", lang);
  }
  if (view.hrOnly) {
    return t("noGps", lang) + " / " + t("distanceUnavailable", lang);
  }
  if (view.distanceMeters <= 0) {
    return t("distanceUnavailable", lang);
  }
  const mark = view.uncertified > 0 || view.unflushed > 0 ? " " + t("uncertified", lang) : "";
  return Math.round(view.distanceMeters) + " m " + t("experimental", lang) + mark;
}

function lines(view, lang) {
  const battery = view.batteryPercent == null ? t("batteryUnavailable", lang) : t("battery", lang) + " " + view.batteryPercent + "%";
  const gap = t("gaps", lang) + " " + view.gaps + " " + t("uncertified", lang) + " " + view.uncertified;
  return {
    hr: hrLabel(view, lang),
    gps: gpsLabel(view.gpsState, lang),
    battery: battery,
    distance: distanceLine(view, lang),
    gap: gap + " " + t("savedNever", lang),
  };
}

function paint(force) {
  const now = Date.now();
  if (!force && now - lastPaint < 1000) {
    return;
  }
  lastPaint = now;
  if (!ui) {
    return;
  }
  const view = host.view();
  const text = lines(view, code());
  ui.setText("hr", text.hr);
  ui.setText("gps", text.gps);
  ui.setText("battery", text.battery);
  ui.setText("distance", text.distance);
  ui.setText("gap", text.gap);
  host.markPaint();
}

function boot() {
  const lang = code();
  const view = host.view();
  ui = mountSession(logDevice("home"), t("title", lang), [
    { name: "hr", label: lines(view, lang).hr, color: 0xc4a35a },
    { name: "gps", label: lines(view, lang).gps },
    { name: "battery", label: lines(view, lang).battery },
    { name: "distance", label: lines(view, lang).distance },
    { name: "gap", label: lines(view, lang).gap },
    { name: "enable", label: t("enableHr", lang), action: () => { host.enableHr(); paint(true); } },
    { name: "start", label: t("startSession", lang), action: () => { host.startSession({ hrOnly: false }); paint(true); } },
    { name: "hronly", label: t("hrOnly", lang), action: () => { host.startSession({ hrOnly: true }); paint(true); } },
    { name: "stop", label: t("stop", lang), action: () => { host.stop(); paint(true); } },
    { name: "diag", label: t("diagnostics", lang), action: () => { host.stop(); push({ url: "page/gt/diagnostics/index.page" }); } },
  ]);
  host.sampleBattery();
  paint(true);
}

Page({
  onInit() {
    bindBack(true);
  },
  build() {
    console.log("FORREF_SENS_V2 boot sensors=OFF service=OFF workout=BIP6_NOT_LISTED d1=UNCERTIFIED");
    boot();
    paintTimer = setInterval(() => {
      host.tick(clock.elapsed());
      paint(false);
    }, 1000);
    batteryTimer = setInterval(() => host.sampleBattery(), 30000);
  },
  onDestroy() {
    if (paintTimer != null) {
      clearInterval(paintTimer);
      paintTimer = null;
    }
    if (batteryTimer != null) {
      clearInterval(batteryTimer);
      batteryTimer = null;
    }
    host.release();
  },
});
