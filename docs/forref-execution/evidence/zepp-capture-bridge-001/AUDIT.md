# Zepp autonomous capture bridge — audit

## Baseline

| Item | Value |
| --- | --- |
| Repository | `ionutlazar2701-source/forref` |
| Branch base | `c993055fbeb4e769174aaf86d5aa4889ee95c21d` |
| PR #44 | `origin/cursor/zepp-live-match-flow-002-30fd` at that SHA |
| PR #45 | `origin/cursor/zepp-true-black-08a-30fd` at `9a180270e39c7982cbd36eea3f26de91f36eea42`, not checked out |
| PR #46 | `origin/cursor/match-report-bridge-001-30fd` at `00587741abceb4bf5900e97c0a034aede8cf46c4`, not checked out |
| PR #47 | `origin/cursor/phone-match-report-ui-002-30fd` at `7848569d3b3fefe5b4685b83708337e31444bd8e`, not checked out |
| Task file | Drive `139nA-WTFOxga-O7xX0SeE9XYlxmRbX3e`, `TASK_CURSOR_ZEPP_AUTONOMOUS_CAPTURE_BRIDGE_001.md` |

The watch branch contains the Zepp cutover note only as history on later PRs. This branch does not merge those PRs. The phone `SqliteDurableMatchStore` remains the only Match Memory writer named by that cutover. This change does not append Match Records.

## What the watch already had

`page/gt/event` stores the display tokens `YELLOW`, `RED`, `GOAL`, or `SUB`. `page/gt/player` stores `PLAYER 9`, `PLAYER 4`, or `UNKNOWN`. `page/gt/review` showed those tokens and `DEMO — RECORDING NOT AVAILABLE`. None of those tokens is a `MatchTeamId` or a `MatchParticipantId`. `RED` is not a send-off. Two yellow selections are not a send-off. A substitution has no two participant ids.

`utils/clock_device.js` still uses `forref_clock001c_state.json` and the LocalStorage key `forref_clock001c_state`. This change does not read or write that file.

There is no pre-provisioned match id or team id on the watch. The simulator-only fixture `SIM_MATCH_001`, `SIM_TEAM_HOME`, `SIM_TEAM_AWAY`, and `SIM_DEVICE_001` is off until the review screen toggles `SIM FIXTURE`. Ordinary `HOME` / `AWAY` stays an incomplete draft.

## Filesystem API

App API target in `app.json` is `4.0`. The public file API used by the adapter starts at API_LEVEL 2.0:

- `openSync`: https://docs.zepp.com/docs/reference/device-app-api/newAPI/fs/openSync/
- `writeSync`: https://docs.zepp.com/docs/reference/device-app-api/newAPI/fs/writeSync/ — returns the number of bytes written
- `readSync`: https://docs.zepp.com/docs/reference/device-app-api/newAPI/fs/readSync/
- `closeSync`: https://docs.zepp.com/docs/reference/device-app-api/newAPI/fs/closeSync/ — `0` means the descriptor closed
- `statSync`: https://docs.zepp.com/docs/reference/device-app-api/newAPI/fs/statSync/
- LocalStorage: https://docs.zepp.com/docs/reference/device-app-api/newAPI/storage/localStorage/ — a local key-value API, not a transaction

Those pages document a byte count and a closed descriptor. They do not document `fsync`, a storage barrier, power-loss atomicity, wear leveling, or a durable commit. `O_APPEND` is documented as append-to-end. It is not documented as an atomic record write. This bridge treats a short `writeSync` count as unverified and does not call the result Saved.

`readCaptureJournal` treats `ENOENT`, a not-found message, or a null `stat` as a missing journal. A zero-byte stat is a verified empty file. Any other `stat` or `read` error is unverified. The journal refuses to append after that read, including when the failure happens on the capacity re-read.

Zeus on this VM: `1.10.0`. At 22:26 Europe/Bucharest on 16 Nov 2026, `zeus status` reported `login status: no login` and `simulator connect status: disconnected`. The 17 Nov 2026 guest run superseded that check. Simulator 2.1.2 was already installed. `qemu-system-arm` lives in the simulator package at `resources/firmware/qemu_linux/`. The first launches failed on a missing `libaio.so.1`. After that library was present, `zeus dev` connected to `127.0.0.1:7650` with CLI login still absent. Guest `getDeviceInfo()` is in `guest/guest-console.txt`: Bip 6 `390×450` `RECT` source `10158337`, and Amazfit Active Max `480×480` `ROUND` source `10813699`.

The task file was downloaded and read before the code change. The required SHA-256 is `30fb31aedf2362e66c811748dc9b0dcc2093c0e66a81095c6b66074a1de4403f`. This run did not persist a second byte copy of that download, so this folder does not claim a recomputed match.

## Toolchain observed here

Dart 3.13.2, Flutter 3.47.2, Node from the npm test log, Zeus CLI 1.10.0. The guest run observed Bip 6 firmware cache `4ae8ec66a7e2d342faf040652f4f41ff` and Active Max firmware cache `dd7ed809e0ed0ecdffc68ccf5682463b`. Screen shape and device source are in the guest console cited above.
