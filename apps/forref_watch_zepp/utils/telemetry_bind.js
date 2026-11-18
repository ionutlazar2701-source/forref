import { Geolocation, HeartRate } from "@zos/sensor";
import { createTimer, stopTimer } from "@zos/timer";
import { createMatchTelemetry, installMatchTelemetry, releaseMatchTelemetry } from "./telemetry.js";
import { createTelemetryHost } from "./telemetry_host.js";
import { deviceTelemetryStore } from "./telemetry_store.js";

let origin = 0;

function elapsed() {
  if (!origin) {
    origin = Date.now();
  }
  return Date.now() - origin;
}

export function attachMatchTelemetry(epoch) {
  const engine = createMatchTelemetry({ epoch: epoch || "", store: deviceTelemetryStore() });
  const host = createTelemetryHost({ Geolocation: Geolocation, HeartRate: HeartRate }, engine, { elapsed: elapsed }, {
    set: function (fn, ms) {
      const id = createTimer(ms, ms, function () {
        stopTimer(id);
        fn();
      });
      return id;
    },
    clear: function (id) {
      stopTimer(id);
    },
  });
  installMatchTelemetry(host);
  globalThis.__FORREF_TELEMETRY_RELEASE = releaseMatchTelemetry;
  console.log("FORREF_TEL attach=1 saved=0");
}

export { releaseMatchTelemetry };
