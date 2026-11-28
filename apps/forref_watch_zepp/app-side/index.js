import { BaseSideService } from "@zeppos/zml/base-side";
import { replyLink } from "../utils/link_channel.js";
import { PROVISION_BRIDGE_URL, dispatchSideRequest } from "../utils/provision_bridge.js";

AppSideService(
  BaseSideService({
    onInit() {
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
      dispatchSideRequest(req, (options) => this.fetch(options)).then((body) => {
        res(null, body);
      });
    },
  }),
);
