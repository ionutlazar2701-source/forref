# Local gates

Tasks that **Cloud Agents cannot certify**. Cloud Agents may prepare code, tests, and docs for these areas but must report **`LOCAL GATE REQUIRED`** when the physical or credential gate has not passed locally.

## Physical device and field validation

| Gate | Why cloud is insufficient |
| --- | --- |
| Physical Garmin deployment | Connect IQ build, sideload, and on-device store/beta flows need hardware and Garmin tooling |
| Physical smartwatch behavior (Wear OS, watchOS) | Touch targets, round/square layouts, wrist UX, and wake/ambient behavior |
| Bluetooth / phone–watch link validation | Real pairing, drop/reconnect, and autonomy boundaries |
| Real battery measurement | 90+ minute outdoor match with GPS, HR, vibration, and screen-on |
| Power-loss / device durability certification | Abrupt power-off during D1 commit; not reproducible on ephemeral VMs |
| Hardware-specific temporal certification | Monotonic clock drift, background throttling, and OS timer policy on real devices |
| Outdoor pitch checklist | Sun, sweat, gloves, rain — [hardware-test-matrix.md](hardware-test-matrix.md) |

## Platform signing and credentials

| Gate | Why cloud is insufficient |
| --- | --- |
| iOS / watchOS signing & TestFlight | Apple developer certificates and provisioning profiles |
| Android / Wear OS Play signing | Upload keys and Play Console closed-track promotion |
| Garmin Connect IQ signing | Developer keys and device-specific install |

## Performance and emulator limits

| Gate | Why cloud is insufficient |
| --- | --- |
| Phone/watch performance certification | Cloud VM timings are not phone or watch performance |
| Emulator-only “match complete” claims | Emulators lack real GPS, battery, Bluetooth drop, and outdoor conditions — see [testing.md](testing.md) |
| PERF-MEASURE-001 baseline capture | Benchmark artifacts are machine-local; `packages/forref_match_benchmark` is measurement-only |

## Cloud-capable (repository verification)

These **are** certified by `./tool/verify_cloud.sh` on a Linux cloud workspace:

- Pure-Dart Match Core analysis and tests (`packages/forref_match_core`)
- D1 persistence analysis and tests (`packages/forref_match_persistence`)
- Flutter phone shell analysis and tests (`apps/referee_phone`)

Do **not** treat a green cloud run as substitute for any gate in the tables above.
