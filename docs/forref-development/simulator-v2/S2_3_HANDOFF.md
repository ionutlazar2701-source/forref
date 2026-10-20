# S2.3 handoff — integration sandbox and event journal

PROGRAM: FORREF SIMULATOR V2
WAVE: S2.3
STATUS: PASS

INPUT SHA: `fc38d18aa6527866b49bb159b475867af05d9ec9`
IMPLEMENTATION TIP: `68780d5569aebeb32126837434bd1d4ee768da26`

Sandbox package commit: `bed8991`

PRODUCTION AUTHORITY MODIFIED: NO

`git diff 0922f1ff97a3f9bec1c052f18fc9db485515316e -- packages apps` is empty.

## Banks

| Bank | Result |
| --- | --- |
| S2.3-A Sandbox package | PASS |
| S2.3-B Database isolation | PASS |
| S2.3-C Existing capture contract | PASS for v1 yellow. Other events are not faked |
| S2.3-D Event journal | PASS |
| S2.3-E Success contract | PASS |
| S2.3-F Storage evidence | PASS as desktop measurement |
| S2.3-G Reopen / rebuild | PASS |

## Bridges

| Bridge | Result |
| --- | --- |
| Watch/operator intent text → frozen yellow meaning | PASS inside the sandbox session |
| Frozen meaning → production capture admission | PASS |
| Admission → `SqliteDurableMatchStore.commit` | PASS |
| Commit → readback → projection → journal label | PASS |

The lab buttons call the same session. The screenshot renderer displays a report produced by `dart run bin/capture_report.dart` because opening SQLite inside a Flutter widget test did not complete. The file-backed proof is the Dart test and that script, not the widget binding.

## Observed capture

Synthetic yellow `sim-intent-report-yellow` for `sim-p-14`.

- Store result: `DurableCommitSuccess`
- Record id: `sim-yellow-sim-intent-report-yellow`
- Readback: the same id, payload `YellowCardPayload`
- Label: `SANDBOX D1 COMMITTED`
- Encoded record: 621 bytes
- Database file: 49152 bytes before the yellow and 49152 bytes after. The row fit in the existing page.
- Record count after the yellow: 1
- Projection after reopen contains that record id
- Abort of `sim-intent-report-abort`: `DurableCommitFailure`, label `SANDBOX COMMIT FAILED`
- Duplicate intent: `SANDBOX D1 ALREADY COMMITTED`, same record id, same count

Measurement label: `DESKTOP SANDBOX MEASUREMENT`.

## Tests

| Package | Result |
| --- | --- |
| `research/simulator_sandbox` `dart analyze` | No issues found |
| `research/simulator_sandbox` `dart test` | 7 passed |
| `research/hf_prototype` sandbox journal widget | 1 passed |

INDEPENDENT SABOTEUR NOT AVAILABLE

WINDOWS: not run in this session.

HUMAN VALIDATION: NOT RUN

WATCH HARDWARE: NOT TESTED

## Next safe wave

S2.4 phone shells and the match builder. Phone authority cutover stays HOLD.
