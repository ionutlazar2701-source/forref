import { BaseSideService } from "@zeppos/zml/base-side";
import { sideAnswer } from "../utils/config_probe.js";
import {
  LOCAL_BRIDGE_URL,
  createLocalBridge,
  isLocalMethod,
} from "../utils/local_bridge.js";

const localBridge = createLocalBridge();

AppSideService(
  BaseSideService({
    onInit() {
      console.log("FORREF_PROBE_A side=init source=side-service-static");
      console.log("FORREF_B1 side=init url=" + LOCAL_BRIDGE_URL);
    },
    onRequest(req, res) {
      const method = req && req.method ? req.method : "";
      if (isLocalMethod(method)) {
        const fetchImpl = (url) =>
          this.fetch({
            url: url,
            method: "GET",
            timeout: 4000,
          });
        localBridge
          .answer(req, fetchImpl)
          .then((answer) => {
            console.log(
              "FORREF_B1 side method=" +
                method +
                " disposition=" +
                answer.data.disposition
            );
            res(answer.error, answer.data);
          })
          .catch(() => {
            console.log("FORREF_B1 side method=" + method + " disposition=unavailable");
            res(null, { disposition: "unavailable" });
          });
        return;
      }
      const answer = sideAnswer(req);
      console.log(
        "FORREF_PROBE_A side method=" +
          method +
          " disposition=" +
          answer.data.disposition
      );
      res(answer.error, answer.data);
    },
  })
);
