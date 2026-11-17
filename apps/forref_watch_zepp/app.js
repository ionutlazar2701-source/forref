import { bootLine } from "./utils/build_stamp";

App({
  globalData: {
    demo: true,
  },
  onCreate() {
    this.globalData = this.globalData || {};
    this.globalData.clockEpoch = "e" + Date.now();
    console.log("FORREF_APP onCreate epoch=" + this.globalData.clockEpoch);
    console.log(bootLine());
    console.log("FORREF_CAPTURE_BOOT namespace=forref_capture_bridge_001 schema=1 d1=UNCERTIFIED");
  },
  onDestroy() {
    console.log("FORREF_APP onDestroy");
  },
});
