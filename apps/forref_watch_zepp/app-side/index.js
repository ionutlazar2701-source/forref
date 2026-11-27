import { BaseSideService } from "@zeppos/zml/base-side";
import {
  PROVISION_BRIDGE_URL,
  PROVISION_DEADLINE_MS,
  fetchWithDeadline,
  isProvisionMethod,
  readTransportPayload,
  sideFetchBody,
} from "../utils/provision_bridge.js";

function reply(res, method, normalized) {
  const disposition = normalized && normalized.ok ? normalized.disposition : normalized && normalized.disposition === "refused" ? "refused" : "unavailable";
  const reason = normalized && normalized.reason ? normalized.reason : "";
  console.log("FORREF_PROVISION tx=response method=" + method + " http=" + (normalized && normalized.httpStatus != null ? normalized.httpStatus : "") + " disposition=" + disposition + " reason=" + reason);
  if (normalized && normalized.ok) {
    res(null, normalized.body);
    return;
  }
  res(null, { disposition: disposition, reason: reason || "unavailable", durable: false });
}

AppSideService(
  BaseSideService({
    onInit() {
      console.log("FORREF_PROVISION side=init url=" + PROVISION_BRIDGE_URL);
    },
    onRequest(req, res) {
      const method = req && req.method ? req.method : "";
      if (!isProvisionMethod(method)) {
        console.log("FORREF_PROVISION tx=response method=" + method + " disposition=refused reason=method");
        res(null, { disposition: "refused", reason: "method", durable: false });
        return;
      }
      const body = sideFetchBody(method, req.params || {});
      if (!body) {
        console.log("FORREF_PROVISION tx=response method=" + method + " disposition=refused reason=message");
        res(null, { disposition: "refused", reason: "message", durable: false });
        return;
      }
      console.log("FORREF_PROVISION tx=request method=" + method + " installation=" + body.installationId + " request=" + body.requestId + " match=" + (body.matchId || "") + " hash=" + (body.contentHash || ""));
      fetchWithDeadline(() => this.fetch({
        url: PROVISION_BRIDGE_URL,
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      }), PROVISION_DEADLINE_MS).then((response) => readTransportPayload(response)).then((normalized) => {
        reply(res, method, normalized);
      }).catch((err) => {
        const reason = err && err.reason === "deadline" ? "deadline" : "unavailable";
        console.log("FORREF_PROVISION tx=recover method=" + method + " reason=" + reason + " request=" + body.requestId);
        res(null, { disposition: "unavailable", reason: reason, durable: false });
      });
    },
  }),
);
