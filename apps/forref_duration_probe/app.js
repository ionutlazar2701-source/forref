import { getDeviceInfo } from "@zos/device";

App({
  onCreate() {
    let source = "fail";
    let name = "fail";
    try {
      const info = getDeviceInfo();
      source = info && info.deviceSource != null ? info.deviceSource : "fail";
      name = info && info.deviceName ? info.deviceName : "fail";
    } catch (err) {
      source = "fail";
      name = "fail";
    }
    console.log("DUR001 boot source=" + source + " name=" + name + " api=getSportData");
  },
  onDestroy() {},
});
