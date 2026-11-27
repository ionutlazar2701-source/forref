import { BaseSideService } from "@zeppos/zml/base-side";
import {
  PROVISION_BRIDGE_URL,
  isProvisionMethod,
  sideFetchBody,
} from "../utils/provision_bridge.js";

function asObject(value) {
  if (!value) return null;
  if (typeof value === "string") {
    try {
      return JSON.parse(value);
    } catch (err) {
      return null;
    }
  }
  if (value.body && typeof value.body === "string") return asObject(value.body);
  if (typeof value === "object") return value;
  return null;
}

AppSideService(
  BaseSideService({
    onInit() {
      console.log("FORREF_PROVISION side=init url=" + PROVISION_BRIDGE_URL);
    },
    onRequest(req, res) {
      const method = req && req.method ? req.method : "";
      if (!isProvisionMethod(method)) {
        console.log("FORREF_PROVISION side method=" + method + " disposition=refused");
        res(null, { disposition: "refused", reason: "method" });
        return;
      }
      const body = sideFetchBody(method, req.params || {});
      if (!body) {
        console.log("FORREF_PROVISION side method=" + method + " disposition=refused");
        res(null, { disposition: "refused", reason: "message" });
        return;
      }
      this.fetch({
        url: PROVISION_BRIDGE_URL,
        method: "POST",
        timeout: 4000,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      }).then((response) => {
        const data = asObject(response);
        if (!data || data.disposition == null) {
          console.log("FORREF_PROVISION side method=" + method + " disposition=unavailable");
          res(null, { disposition: "unavailable" });
          return;
        }
        console.log("FORREF_PROVISION side method=" + method + " disposition=" + data.disposition);
        res(null, data);
      }).catch(() => {
        console.log("FORREF_PROVISION side method=" + method + " disposition=unavailable");
        res(null, { disposition: "unavailable" });
      });
    },
  }),
);
