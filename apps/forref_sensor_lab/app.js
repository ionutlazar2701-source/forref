App({
  onCreate() {
    console.log("FORREF_SENS_V2 boot sensors=OFF service=OFF workout=BIP6_NOT_LISTED d1=UNCERTIFIED");
  },
  onDestroy() {
    const release = globalThis.__FORREF_SENS_RELEASE;
    if (typeof release === "function") {
      release();
    }
    console.log("FORREF_SENS_V2 app=onDestroy sensors=OFF d1=UNCERTIFIED");
  },
});