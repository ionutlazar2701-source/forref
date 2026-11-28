// Registers the device App and boots the clock. This module must not import
// @zeppos/zml. BaseApp's module constructs TransferFile, and BaseApp() itself
// reads __$$app$$__.__globals__.__scopedGlobals__ before App() is registered.

export function openDeviceApp(AppHost, hooks) {
  const options = {
    globalData: { demo: true },
    onCreate() {
      try {
        hooks.onCreate(this);
      } catch (err) {
        hooks.log("FORREF_APP tx=recover reason=boot detail=" + hooks.detail(err));
      }
    },
    onDestroy() {
      try {
        hooks.onDestroy(this);
      } catch (err) {
        hooks.log("FORREF_APP tx=recover reason=shutdown detail=" + hooks.detail(err));
      }
    },
  };
  AppHost(options);
  return options;
}
