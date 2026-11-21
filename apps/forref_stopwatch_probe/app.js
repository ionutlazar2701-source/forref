import { getDeviceInfo } from "@zos/device";

App({
  onCreate() {
    let source = "fail";
    try {
      const info = getDeviceInfo();
      source = info && info.deviceSource != null ? info.deviceSource : "fail";
    } catch (err) {
      source = "fail";
    }
    console.log("SW001 boot source=" + source + " read=NO_PUBLIC_READ");
  },
  onDestroy() {},
});
