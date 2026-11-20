// Device binding for the background sampler. The lifecycle decisions live in
// clock_service_policy.js so tests can supply an SDK-faithful mock.

import { queryPermission, requestPermission } from "@zos/app";
import { getAllAppServices, start, stop } from "@zos/app-service";
import { createServiceHost } from "./clock_service_policy.js";

const host = createServiceHost({
  queryPermission: queryPermission,
  requestPermission: requestPermission,
  start: start,
  stop: stop,
  getAllAppServices: getAllAppServices,
});

export function syncClockService(session) {
  host.sync(session);
}

export function clockHostSnapshot() {
  return host.snapshot();
}
