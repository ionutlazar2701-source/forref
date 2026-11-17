App({
  onCreate() {
    console.log("FORREF_SENS_BOOT namespace=forref_sens_001 schema=1 gnss=FOREGROUND_ONLY service=HR_ONLY workout=BIP6_NOT_LISTED d1=UNCERTIFIED");
  },
  onDestroy() {
    console.log("FORREF_SENS app=onDestroy d1=UNCERTIFIED");
  },
});
