import { back } from "@zos/router";
import { appPlugin } from "@zeppos/zml/3.0/module/messaging/plugin/app";
import { bindBack, clear, logDevice, stack } from "../../../utils/chrome";
import { attachDeviceMessaging } from "../../../utils/device_messaging";
import { isPong, nextLinkSeq, pingRequest } from "../../../utils/link_channel";
import { t } from "../../../utils/text";

const LINK_TIMEOUT_MS = 8000;

function detail(err) {
  const message = err && err.message ? String(err.message) : String(err || "exception");
  return message.slice(0, 120);
}

function loadPlugin() {
  return Promise.resolve(typeof appPlugin === "function" ? appPlugin : null);
}

Page({
  onInit() {
    this._status = "ready";
    this._busy = false;
    console.log("FORREF_LINK page=init");
  },
  build() {
    console.log("FORREF_LINK page=build");
    try {
      bindBack(false);
    } catch (err) {
      console.log("FORREF_LINK tx=recover reason=back detail=" + detail(err));
    }
    this.paint();
  },
  paint() {
    const m = logDevice("link");
    clear();
    const status = this._status === "pong" ? t("linkPong") : this._status === "wait" ? t("linkWait") : this._status === "down" ? t("linkDown") : t("linkReady");
    stack(m, t("link"), [
      { label: status },
      { label: t("linkPing"), action: () => this.ping(), name: "link-ping" },
      { label: t("back"), action: () => back(), name: "link-back" },
    ]);
  },
  ping() {
    if (this._busy) return;
    this._busy = true;
    this._status = "wait";
    this.paint();
    let app = null;
    try {
      app = globalThis.getApp();
    } catch (err) {
      console.log("FORREF_LINK tx=recover reason=app detail=" + detail(err));
    }
    if (!app || !app.globalData) {
      this.finish("down", "app", 0);
      return;
    }
    const seq = nextLinkSeq(app.globalData);
    console.log("FORREF_LINK tx=ping seq=" + seq);
    loadPlugin().then((plugin) => {
      let messaging = null;
      try {
        messaging = attachDeviceMessaging(app, plugin);
      } catch (err) {
        console.log("FORREF_LINK tx=recover reason=init detail=" + detail(err) + " seq=" + seq);
      }
      if (!messaging) {
        this.finish("down", "messaging", seq);
        return null;
      }
      console.log("FORREF_LINK messaging=ready seq=" + seq);
      return messaging.request(pingRequest(seq), { timeout: LINK_TIMEOUT_MS }).then((body) => {
        if (isPong(body, seq)) this.finish("pong", "", seq);
        else this.finish("down", "body", seq);
      });
    }).catch((err) => {
      this.finish("down", "request", seq, detail(err));
    });
  },
  finish(status, reason, seq, extra) {
    this._busy = false;
    this._status = status;
    if (status === "pong") console.log("FORREF_LINK tx=pong seq=" + seq);
    else console.log("FORREF_LINK tx=recover reason=" + reason + " seq=" + seq + (extra ? " detail=" + extra : ""));
    try {
      this.paint();
    } catch (err) {
      console.log("FORREF_LINK tx=recover reason=paint detail=" + detail(err));
    }
  },
});
