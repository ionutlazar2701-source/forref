// Opens the device App with ZML messaging on globalData, then the clock boot.
// A messaging failure must not skip the clock. The provision page reads
// globalData.messaging and does not use BasePage.

export function messagingAttached(globalData) {
  const messaging = globalData && globalData.messaging;
  return !!(
    messaging &&
    typeof messaging.request === "function" &&
    typeof messaging.onCall === "function"
  );
}

export function openDeviceApp(AppHost, BaseAppHost, hooks) {
  const options = BaseAppHost({
    globalData: { demo: true },
    onCreate() {
      hooks.onCreate(this);
    },
    onDestroy() {
      hooks.onDestroy(this);
    },
  });
  const start = options.onCreate;
  options.onCreate = function (...args) {
    try {
      start.apply(this, args);
    } catch (err) {
      hooks.log(
        "FORREF_PROVISION tx=recover reason=messaging-init detail=" + hooks.detail(err),
      );
      if (!this.globalData || !this.globalData.clockEpoch) {
        try {
          hooks.onCreate(this);
        } catch (clockErr) {
          hooks.log("FORREF_APP tx=recover reason=boot detail=" + hooks.detail(clockErr));
        }
      }
    }
    const ready = messagingAttached(this.globalData);
    hooks.log("FORREF_PROVISION messaging=" + (ready ? "ready" : "absent"));
  };
  AppHost(options);
  return options;
}
