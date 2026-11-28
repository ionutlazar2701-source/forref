import { setWakeUpRelaunch } from "@zos/display";
import { bootLine } from "./utils/build_stamp";
import { startForegroundClock, stopForegroundClock } from "./utils/clock_foreground_bind";
import { openDeviceApp } from "./utils/device_app";
import { attachMatchTelemetry, releaseMatchTelemetry } from "./utils/telemetry_bind";

// Plain App registration. @zeppos/zml BaseApp reads
// __$$app$$__.__globals__.__scopedGlobals__ and opens BLE before App()
// runs. 1.0.20 did that: Bip 6 stayed black, then rebooted.
// Messaging is attached from the provision page, after Home has painted.

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

openDeviceApp(App, {
  onCreate: boot,
  onDestroy: shutdown,
  log: (line) => console.log(line),
  detail: detail,
});
