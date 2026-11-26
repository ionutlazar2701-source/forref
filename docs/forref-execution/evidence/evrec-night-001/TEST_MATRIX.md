# Test matrix — EVREC-NIGHT-001

Executed means a command in this run printed a pass. Specified means the scenario is written and was not run on hardware.

| Check | Status | Result |
| --- | --- | --- |
| N1 concurrent prepare versus phone root, idempotent retry, conflicting document, reserved-match root refusal, close/reopen, exact pre-lock cancel | Executed | `dart test` inside `./tool/verify_cloud.sh`. `watch_provision_n1_test.dart` reached `All tests passed!` for `packages/forref_match_persistence` (98 tests in that package log). |
| Phone cancel before lock | Executed | Included in `apps/referee_phone` flutter tests run by the same script. See `STAGE_RESULTS.md` for the script exit. |
| Dart provision messages: readback required, lost activation is not durable | Executed | `watch_provision_v1_test.dart` inside the match_core package run of the same script (`All tests passed!`, 401 tests). |
| Watch provision admission | Executed | `npm test` in `apps/forref_watch_zepp`: 208 tests, 0 failed. Includes `test/watch_provision.test.js`. |
| Goal journal: first goal, same intent, different team, two goals, reopen, uncertain retry, short write, read failure, duplicate origin, record id, installation, transport false, TIME_UNVERIFIED, 100 entries | Executed | Same `npm test`, `test/goal_journal.test.js`. |
| Local test score: 0–0, 1–0, retry, 1–1, reopen, unavailable, conflict, hidden without activation | Executed | Same `npm test`, `test/local_test_score.test.js`. |
| Dart KnownScore numerals versus the local-test fixture (`knownScore` false on the watch object) | Executed | `watch_goal_v1_test.dart` inside the match_core run. |
| Live geometry, bilingual labels, theme isolation | Executed | Same `npm test`, `test/live_surface.test.js` and `test/theme.test.js`. |
| Message codec, installation UUID stability, lost ack, conflicting activation, short file write | Executed | Same `npm test`, `test/provision_transport.test.js`. |
| `./tool/verify_cloud.sh` | Executed | Command and exit status are in `STAGE_RESULTS.md`. |
| Zepp simulator and `.zab` | Not run | No device toolchain invocation produced a package in this run. |
| Bip 6 provision, restart, Bluetooth off, two goals, score persistence, notification, other app, 45 and 90 minutes, battery, interrupted ack, power loss | Specified only | `HARDWARE_PROTOCOL.md`. Not a physical pass. |
| Yellow, send-off, substitution writers | Not implemented | `N5_GAP_MATRIX.md`. |
