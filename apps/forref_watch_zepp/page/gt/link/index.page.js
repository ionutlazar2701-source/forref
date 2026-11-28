import { back } from "@zos/router";
import { appPlugin } from "@zeppos/zml/3.0/module/messaging/plugin/app";
import { bindBack, clear, logDevice, stack } from "../../../utils/chrome";
import { attachDeviceMessaging, nextLinkVisit, retireLinkVisit } from "../../../utils/device_messaging";
import { isPong, nextLinkSeq, pingRequest } from "../../../utils/link_channel";
import { t } from "../../../utils/text";

const LINK_TIMEOUT_MS = 8000;

function detail(err) {
  const message = err && err.message ? String(err.message) : String(err || "exception");
  return message.slice(0, 120);
}

function failureReason(err) {
  const message = detail(err);
  if (/timeout/i.test(message)) return "timeout";
  if (/ble disconnect/i.test(message)) return "ble";
  if (/side service/i.test(message)) return "side";
  if (/shake/i.test(message)) return "shake";
  return "request";
}

function runningApp() {
  const lookup = globalThis.getApp;
  return typeof lookup === "function" ? lookup() : null;
}

function loadPlugin() {
  return Promise.resolve(typeof appPlugin === "function" ? appPlugin : null);
}

Page({
  onInit() {
    this._status = "ready";
    this._busy = false;
    this._closed = false;
    this._visit = 0;
    try {
      this._visit = nextLinkVisit(runningApp());
    } catch (err) {
      console.log("FORREF_LINK tx=recover reason=visit detail=" + detail(err));
    }
    console.log("FORREF_LINK page=init visit=" + this._visit);
  },
  build() {
    console.log("FORREF_LINK page=build visit=" + this._visit);
    try {
      bindBack(false);
    } catch (err) {
      console.log("FORREF_LINK tx=recover reason=back detail=" + detail(err));
    }
    this.paint();
  },
  onDestroy() {
    this._closed = true;
    console.log("FORREF_LINK page=destroy visit=" + this._visit);
    try {
      const retired = retireLinkVisit(runningApp(), this._visit);
      console.log("FORREF_LINK tx=retire visit=" + this._visit + " owner=" + (retired ? "cleared" : "kept"));
    } catch (err) {
      console.log("FORREF_LINK tx=recover reason=destroy detail=" + detail(err));
    }
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
    if (this._busy || this._closed) return;
    this._busy = true;
    this._status = "wait";
    this.paint();
    const app = runningApp();
    if (!app || !app.globalData) {
      this.finish("down", "app", 0);
      return;
    }
    const seq = nextLinkSeq(app.globalData);
    console.log("FORREF_LINK tx=ping seq=" + seq + " visit=" + this._visit);
    loadPlugin().then((plugin) => {
      if (this._closed) {
        this.finish("down", "destroy", seq);
        return null;
      }
      let messaging = null;
      try {
        messaging = attachDeviceMessaging(app, plugin, this._visit);
      } catch (err) {
        console.log("FORREF_LINK tx=recover reason=init detail=" + detail(err) + " seq=" + seq);
      }
      if (!messaging) {
        this.finish("down", "messaging", seq);
        return null;
      }
      console.log("FORREF_LINK messaging=ready seq=" + seq + " visit=" + this._visit);
      return messaging.request(pingRequest(seq), { timeout: LINK_TIMEOUT_MS }).then((body) => {
        if (isPong(body, seq)) this.finish("pong", "", seq);
        else this.finish("down", "body", seq);
      });
    }).catch((err) => {
      this.finish("down", failureReason(err), seq, detail(err));
    });
  },
  finish(status, reason, seq, extra) {
    this._busy = false;
    if (this._closed) {
      console.log("FORREF_LINK tx=drop seq=" + seq + " reason=" + (reason || status));
      return;
    }
    this._status = status;
    if (status === "pong") console.log("FORREF_LINK tx=pong seq=" + seq + " visit=" + this._visit);
    else if (reason === "timeout") console.log("FORREF_LINK tx=timeout seq=" + seq + (extra ? " detail=" + extra : ""));
    else console.log("FORREF_LINK tx=recover reason=" + reason + " seq=" + seq + (extra ? " detail=" + extra : ""));
    try {
      this.paint();
    } catch (err) {
      console.log("FORREF_LINK tx=recover reason=paint detail=" + detail(err));
    }
  },
});
