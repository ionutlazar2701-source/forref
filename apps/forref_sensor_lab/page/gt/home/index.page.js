import { push } from "@zos/router";
import { Geolocation, HeartRate, Distance, Battery } from "@zos/sensor";
import { getLanguage } from "@zos/settings";
import { start as startService } from "@zos/app-service";
import { bindBack, clear, logDevice, stack } from "../../../utils/chrome";
import { t } from "../../../utils/text";
import { createJournal } from "../../../lib/journal";
import { createSensorHost } from "../../../lib/host";
import { deviceAdapter } from "../../../utils/device_fs";

const clock = {
  origin: Date.now(),
  elapsed() {
    return Date.now() - this.origin;
  },
  utc() {
    return Date.now();
  },
};

const journal = createJournal(deviceAdapter());
const host = createSensorHost({
  Geolocation: Geolocation,
  HeartRate: HeartRate,
  Distance: Distance,
  Battery: Battery,
}, journal, clock);

let armedDelete = false;
let note = "stopped";

function code() {
  try {
    return getLanguage();
  } catch (err) {
    return -1;
  }
}

function paint() {
  const m = logDevice("home");
  clear();
  const running = host.running();
  stack(m, t("title", code()), [
    { label: t(running ? "sampling" : note, code()), color: 0xc4a35a },
    { label: t("start", code()), name: "sens-start", action: () => { armedDelete = false; const result = host.start(); note = result.ok ? "sampling" : (result.reason === "PERMISSION_DENIED" ? "permissionDenied" : "gnssUnavailable"); paint(); } },
    { label: t("stop", code()), name: "sens-stop", action: () => { host.stop(); note = "samplingStopped"; paint(); } },
    { label: t("status", code()), name: "sens-status", action: () => push({ url: "page/gt/status/index.page" }) },
    { label: t("track", code()), name: "sens-track", action: () => push({ url: "page/gt/track/index.page" }) },
    { label: t("heat", code()), name: "sens-heat", action: () => push({ url: "page/gt/heat/index.page" }) },
    { label: t(armedDelete ? "deleteConfirm" : "deleteLocal", code()), name: "sens-delete", action: () => {
      if (!armedDelete) {
        armedDelete = true;
        paint();
        return;
      }
      host.stop();
      const cleared = journal.clear();
      armedDelete = false;
      note = cleared.ok ? "deleted" : "corrupt";
      paint();
    } },
    { label: t("serviceHrOnly", code()), name: "sens-service", action: () => {
      host.stop();
      note = "samplingStopped";
      try {
        startService({
          file: "app-service/hr_only",
          param: "",
          reload: false,
          complete_func: (option) => {
            console.log("FORREF_SENS service=hr result=" + (option && option.result === true ? 1 : 0) + " gnss=UNSUPPORTED d1=UNCERTIFIED");
          },
        });
      } catch (err) {
        console.log("FORREF_SENS service=hr result=0 reason=UNAVAILABLE gnss=UNSUPPORTED d1=UNCERTIFIED");
      }
      paint();
    } },
  ]);
}

Page({
  onInit() {
    bindBack(true);
  },
  build() {
    console.log("FORREF_SENS_BOOT namespace=forref_sens_001 schema=1 gnss=FOREGROUND_ONLY service=HR_ONLY workout=BIP6_NOT_LISTED d1=UNCERTIFIED");
    paint();
  },
  onDestroy() {
    armedDelete = false;
    host.noteLifecycle("APP_EXIT");
  },
});
