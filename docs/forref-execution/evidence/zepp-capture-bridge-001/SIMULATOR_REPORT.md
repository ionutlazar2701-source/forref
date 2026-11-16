# Simulator report

## Guest status

| Check | Observed at 22:26 Europe/Bucharest, 16 Nov 2026 |
| --- | --- |
| Zeus CLI | 1.10.0, installed under `/home/ubuntu/.local` |
| `zeus status` | `login status: no login` |
| Simulator | `disconnected`, host `127.0.0.1`, port `7650` |
| QEMU | No `qemu-system` binary on this VM |
| `getDeviceInfo()` | Not observed |

The follow-up checked the same VM again. Zeus still reports `login status: no login` and `simulator connect status: disconnected`. No `qemu-system` binary is installed. Round Amazfit Active Max and rectangular Amazfit Bip 6 were not launched. No guest screenshot, console capture, or app-recreation trace exists for this change. ZC15 and ZC16 stay BLOCKED. This is not a simulator PASS.

The raw status text is `zeus-status.txt` beside this file. The node suite log is `zepp-npm-test.log`.

## Commands

| Command | Exit | Count |
| --- | --- | --- |
| `npm test` in `apps/forref_watch_zepp` | 0 | geometry script pass, including stacks of 7 rows, then 42 node tests, 0 failed. The 42 include the previous clock, abandon, and live-surface tests plus the capture tests. |
| `./tool/verify_cloud.sh` from the repository root | 0 | Match Core 377, persistence 92, phone analyze clean, phone tests 126 |

Dart 3.13.2. Flutter 3.47.2. SQLite durability settings were not changed.

## What was built for the guest that was not run

Review, still the existing route, offers:

1. The current team, event, and participant tokens.
2. `SIM FIXTURE OFF` / `SIM FIXTURE ON`, labeled test-only.
3. `CAPTURE TEST`.
4. `VIEW LOCAL`.
5. Back, which still calls the router back and does not touch the clock.

A structured goal is available only while the fixture toggle is on. With the toggle off, capture stays incomplete. The same in-memory intent id is sent again on a second tap. App recreation reads the journal file rather than `state()`.

Live A/C, event, and player pages were not edited. Geometry tests still place Live A and Live C inside the 480 round and 390×450 rectangular safe areas, and stacks of 1 through 6 rows still fit. The review screen uses 6 rows.

## Package

`app.json` remains 23 pages. The new journal file name is separate from `forref_clock001c_state`. No permission was added. No True Black color, sensor API, or Match Core schema file was edited.
