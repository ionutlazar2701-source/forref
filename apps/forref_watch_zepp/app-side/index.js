import { BaseSideService } from "@zeppos/zml/base-side";
import { sideAnswer } from "../utils/config_probe.js";

AppSideService(
  BaseSideService({
    onInit() {
      console.log("FORREF_PROBE_A side=init source=side-service-static");
    },
    onRequest(req, res) {
      const answer = sideAnswer(req);
      const method = req && req.method ? req.method : "";
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
