import { BaseSideService } from "@zeppos/zml/base-side";
import { sideBuildLine } from "../utils/build_stamp.js";
import { replyLink } from "../utils/link_channel.js";
import {
  GET_SIDE_BUILD_V1,
  PROBE_BRIDGE_V1,
  PROVISION_BRIDGE_URL,
  blockedDuringPrepare,
  dispatchSideRequest,
  probeBridge,
  sameBuild,
  sideBuildRecord,
} from "../utils/provision_bridge.js";

AppSideService(
  BaseSideService({
    onInit() {
      console.log(sideBuildLine());
      console.log("FORREF_PROVISION side=init url=" + PROVISION_BRIDGE_URL);
    },
    onRequest(req, res) {
      const link = replyLink(req);
      if (link) {
        if (link.error) {
          console.log("FORREF_LINK tx=recover reason=" + link.error);
          res({ reason: link.error }, null);
          return;
        }
        console.log("FORREF_LINK tx=pong seq=" + link.body.seq);
        res(null, link.body);
        return;
      }
      const method = req && req.method ? req.method : "";
      if (method === GET_SIDE_BUILD_V1) {
        console.log(sideBuildLine());
        res(null, sideBuildRecord());
        return;
      }
      if (method === PROBE_BRIDGE_V1) {
        if (!sameBuild((req && req.params) || {})) {
          console.log("FORREF_PROVISION tx=probe disposition=refused reason=parity");
          res(null, { disposition: "refused", reason: "parity", hop: "side", category: "parity", durable: false });
          return;
        }
        probeBridge((options) => this.fetch(options)).then((body) => {
          res(null, body);
        });
        return;
      }
      if (blockedDuringPrepare(method)) {
        console.log("FORREF_PROVISION tx=side method=" + method + " disposition=refused reason=prepare-only");
        res(null, { disposition: "refused", reason: "prepare-only", hop: "side", category: "prepare-only", durable: false });
        return;
      }
      dispatchSideRequest(req, (options) => this.fetch(options)).then((body) => {
        res(null, body);
      });
    },
  }),
);
