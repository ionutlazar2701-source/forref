# Simulator report

## Guest run

The guest session ran from 00:12 to 01:06 Europe/Bucharest on 17 Nov 2026. The simulator clock was UTC, one zone behind Bucharest. The unedited console panel text is `guest/guest-console.txt`.

Zeus CLI `1.10.0`. `zeus dev` connected to `127.0.0.1:7650`. CLI login stayed absent. After the run, `zeus status` reported `simulator connect status: connected` and `login status: no login`.

Simulator package `2.1.2`. QEMU is `/opt/simulator/resources/firmware/qemu_linux/qemu-system-arm`. The first two launches failed because `libaio.so.1` was missing. Those lines are the opening of the console file. After `libaio1t64` and a `libaio.so.1` soname link, the guest started.

An earlier check at 22:26 Europe/Bucharest on 16 Nov 2026 found no guest. This run replaces that check.

### Bip 6, rectangular

`zeus dev -t "Amazfit Bip 6"` built device sources `9765120`, `9765121`, `10158337`. Storage file: `~/.zepp/emulator_cache/4ae8ec66a7e2d342faf040652f4f41ff/norflash.bin`.

Guest `getDeviceInfo`:

`FORREF_DEVICE page=home width=390 height=450 shape=RECT screenShape=0 keyNumber=2 keyType=normal_20 deviceSource=10158337 deviceName=Bip 6 statusBar=64 safeMargin=12`

Live A after kick-off showed `1ST HALF RUNNING`, the clock display at `00:18` in `guest/bip6-live-running.png`, and `HOME · NO SCORE` / `AWAY · NO SCORE`.

Yellow, PLAYER 9, fixture off:

| Tap | Console |
| --- | --- |
| `CAPTURE TEST` | `seq=1 id=CB1-UNPROVISIONED_DEVICE-0001 admission=INCOMPLETE_IDENTITY evidence=READBACK_MATCHED duplicate=0 d1=UNCERTIFIED` |
| `CAPTURE TEST` again | same id, `reason=IDEMPOTENT duplicate=1` |
| `NEW CAPTURE` | `seq=2 id=CB1-UNPROVISIONED_DEVICE-0002 admission=INCOMPLETE_IDENTITY evidence=READBACK_MATCHED duplicate=0 d1=UNCERTIFIED` |

Fixture on, GOAL, PLAYER 9:

`seq=3 id=CB1-SIM_DEVICE_001-0003 admission=VALID_STRUCTURED_CANDIDATE evidence=READBACK_MATCHED duplicate=0 d1=UNCERTIFIED`

The screen said `LOCAL CANDIDATE #3 — NOT A MATCH RECORD` (`guest/bip6-goal-candidate.png`). View local listed `#1`, `#2`, and `#3` in that order (`guest/bip6-view-local.png`).

Leaving Live A logged `TIMER|stop`. The return screen said `TIME UNVERIFIED` and `LAST KNOWN 00:56`, with both teams still `NO SCORE` (`guest/bip6-live-return.png`). That is the existing clock projection. The capture screen did not present `00:56` as an official minute.

The guest process was closed and opened again on the same norflash. A new `onCreate` ran at 00:40 Europe/Bucharest. Review then logged:

`FORREF_CAPTURE evidence=RECREATION_RECOVERED count=3 id=CB1-UNPROVISIONED_DEVICE-0001,CB1-UNPROVISIONED_DEVICE-0002,CB1-SIM_DEVICE_001-0003 d1=UNCERTIFIED`

The screen said `LOCAL CANDIDATE RECOVERED — D1 UNVERIFIED` and showed the same three ids (`guest/bip6-recovered-view.png`).

### Active Max, round

`zeus dev -t "Amazfit Active Max"` built device sources `10813697`, `10813699`. Storage file: `~/.zepp/emulator_cache/dd7ed809e0ed0ecdffc68ccf5682463b/norflash.bin`. This journal started empty. It does not share the Bip 6 file.

Guest `getDeviceInfo`:

`FORREF_DEVICE page=home width=480 height=480 shape=ROUND screenShape=1 keyNumber=2 keyType=normal_20 deviceSource=10813699 deviceName=Amazfit Active Max statusBar=0 safeMargin=12`

Home is `guest/active-home.png`. Live A after kick-off showed `1ST HALF RUNNING` at `00:20` with `HOME · NO SCORE` / `AWAY · NO SCORE` (`guest/active-live-running.png`).

The same yellow-then-goal sequence on PLAYER 9:

| Tap | Console |
| --- | --- |
| `CAPTURE TEST` | `seq=1 id=CB1-UNPROVISIONED_DEVICE-0001 admission=INCOMPLETE_IDENTITY evidence=READBACK_MATCHED duplicate=0 d1=UNCERTIFIED` |
| `CAPTURE TEST` again | same id, `reason=IDEMPOTENT duplicate=1` |
| `NEW CAPTURE` | `seq=2 id=CB1-UNPROVISIONED_DEVICE-0002 admission=INCOMPLETE_IDENTITY evidence=READBACK_MATCHED duplicate=0 d1=UNCERTIFIED` |
| fixture on, GOAL, `CAPTURE TEST` | `seq=3 id=CB1-SIM_DEVICE_001-0003 admission=VALID_STRUCTURED_CANDIDATE evidence=READBACK_MATCHED duplicate=0 d1=UNCERTIFIED` |

`guest/active-goal-candidate.png` shows `LOCAL CANDIDATE #3 — NOT A MATCH RECORD` and `SIM FIXTURE ON`. View local listed the three ids (`guest/active-view.png`).

The guest was closed and opened again on the same norflash. `onCreate` ran at 01:02 Europe/Bucharest, with `FORREF_CAPTURE_BOOT ... d1=UNCERTIFIED`. Live A then showed `TIME UNVERIFIED` / `LAST KNOWN 00:33` and `NO SCORE` (`guest/active-re-live.png`). Review logged:

`FORREF_CAPTURE evidence=RECREATION_RECOVERED count=3 id=CB1-UNPROVISIONED_DEVICE-0001,CB1-UNPROVISIONED_DEVICE-0002,CB1-SIM_DEVICE_001-0003 d1=UNCERTIFIED`

`guest/active-recovered-view.png` shows that recovered list.

## Limits of this guest run

Hardware D1 and power loss stay uncertified. Every capture line ends with `d1=UNCERTIFIED`.

The phone Match Memory writer was not called. The watch did not show Saved, an official score, or a match report.

The clock lines are the existing live projection (`OBSERVED_UNVERIFIED`, `TIME_UNVERIFIED`, `FROZEN_OBSERVED`). They are not temporal authority.

Live C was not opened. Locale stayed `en-US` from the OS (`reason=os`). Romanian strings were not shown on the guest.

## Verdict

| Line | Result |
| --- | --- |
| Implementation | PARTIAL |
| Simulator round (Active Max) | PASS_OBSERVATION_ONLY |
| Simulator rectangular (Bip 6) | PASS_OBSERVATION_ONLY |
| Local journal on the guest filesystem | PASS_OBSERVATION_ONLY |
| Match Memory authority | NOT ENABLED |
| D1 / power-loss | NOT CERTIFIED |
| Official match report on the watch | NOT IMPLEMENTED |
| Temporal authority | NOT CERTIFIED |

ZC15 and ZC16, the two guest-shape gates that were blocked while no QEMU guest existed, are the round and rectangular rows above.

## Commands

| Command | Exit | Count |
| --- | --- | --- |
| `npm test` in `apps/forref_watch_zepp` | 0 | geometry pass, then 42 node tests, 0 failed |
| `./tool/verify_cloud.sh` from the repository root | 0 | Match Core 377, persistence 92, phone analyze clean, phone tests 126 |

This guest update did not change application code. Dart 3.13.2. Flutter 3.47.2. SQLite durability settings were not changed.
