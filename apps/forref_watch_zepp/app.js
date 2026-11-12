App({
  globalData: {
    demo: true,
  },
  onCreate() {
    this.globalData = this.globalData || {};
    this.globalData.clockEpoch = "e" + Date.now();
    console.log("FORREF_APP onCreate epoch=" + this.globalData.clockEpoch);
    console.log("FORREF_LIVE002_BOOT build=live-match-flow-002!");
  },
  onDestroy() {
    console.log("FORREF_APP onDestroy");
  },
});
