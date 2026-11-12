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
  },
  onDestroy() {
    console.log("FORREF_APP onDestroy");
  },
});
