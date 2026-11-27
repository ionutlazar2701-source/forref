import { setWakeUpRelaunch } from "@zos/display";
import { BaseApp } from "@zeppos/zml/base-app";
import { bootLine } from "./utils/build_stamp";
import { startForegroundClock, stopForegroundClock } from "./utils/clock_foreground_bind";
import { openDeviceApp } from "./utils/device_app";
import { attachMatchTelemetry, releaseMatchTelemetry } from "./utils/telemetry_bind";

function detail(err) {
  const message = err && err.message ? String(err.message) : String(err || "exception");
  return message.slice(0, 120);
}

function boot(app) {
  app.globalData = app.globalData || {};
  app.globalData.clockEpoch = "e" + Date.now();
  console.log("FORREF_APP onCreate epoch=" + app.globalData.clockEpoch);
  console.log(bootLine());
  console.log("FORREF_CAPTURE_BOOT namespace=forref_capture_bridge_001 schema=1 d1=UNCERTIFIED");
  try {
    setWakeUpRelaunch({ relaunch: true });
    console.log("FORREF_CLOCK_SLEEP relaunch=on");
  } catch (err) {
    console.log("FORREF_CLOCK_SLEEP relaunch=unavailable");
  }
  try {
    startForegroundClock();
  } catch (err) {
    console.log("FORREF_CLOCK_FG timer=unavailable");
  }
  try {
    attachMatchTelemetry(app.globalData.clockEpoch);
  } catch (err) {
    console.log("FORREF_TEL attach=FAILED");
  }
}

function shutdown() {
  try {
    stopForegroundClock();
  } catch (err) {
    console.log("FORREF_CLOCK_FG timer-stop=fail");
  }
  try {
    releaseMatchTelemetry();
  } catch (err) {
    console.log("FORREF_TEL release=FAILED");
  }
  console.log("FORREF_APP onDestroy");
}

openDeviceApp(App, BaseApp, {
  onCreate: boot,
  onDestroy: shutdown,
  log: (line) => console.log(line),
  detail: detail,
});
