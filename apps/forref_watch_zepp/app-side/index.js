import { BaseSideService } from "@zeppos/zml/base-side";
import { PROVISION_BRIDGE_URL, dispatchSideRequest } from "../utils/provision_bridge.js";

AppSideService(
  BaseSideService({
    onInit() {
      console.log("FORREF_PROVISION side=init url=" + PROVISION_BRIDGE_URL);
    },
    onRequest(req, res) {
      dispatchSideRequest(req, (options) => this.fetch(options)).then((body) => {
        res(null, body);
      });
    },
  }),
);
