import { HeartRate } from "@zos/sensor";
import { createJournal } from "../lib/journal";
import { deviceAdapter } from "../utils/device_fs";

const hr = new HeartRate();
const journal = createJournal(deviceAdapter());
const origin = Date.now();

function onHr() {
  let bpm = null;
  try {
    bpm = hr.getCurrent();
  } catch (err) {
    bpm = null;
  }
  const stored = journal.append({
    kind: "HR",
    hrBpm: typeof bpm === "number" && isFinite(bpm) ? bpm : null,
    source: "APP_SERVICE",
    flags: bpm == null ? ["HR_UNAVAILABLE"] : [],
    diagnosticElapsedMs: Date.now() - origin,
    diagnosticUtcMs: Date.now(),
  });
  console.log("FORREF_SENS service=hr stored=" + (stored.ok ? 1 : 0) + " reason=" + (stored.reason || "") + " gnss=UNSUPPORTED d1=UNCERTIFIED");
}

AppService({
  onInit() {
    console.log("FORREF_SENS service=hr onInit gnss=UNSUPPORTED d1=UNCERTIFIED");
    try {
      hr.onCurrentChange(onHr);
    } catch (err) {
      console.log("FORREF_SENS service=hr stored=0 reason=HR_UNAVAILABLE gnss=UNSUPPORTED d1=UNCERTIFIED");
    }
  },
  onDestroy() {
    try {
      hr.offCurrentChange(onHr);
    } catch (err) {
      console.log("FORREF_SENS service=hr stop=failed gnss=UNSUPPORTED d1=UNCERTIFIED");
    }
    console.log("FORREF_SENS service=hr onDestroy gnss=UNSUPPORTED d1=UNCERTIFIED");
  },
});
