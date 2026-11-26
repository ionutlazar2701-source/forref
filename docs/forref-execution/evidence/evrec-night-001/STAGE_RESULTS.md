# Stage results — EVREC-NIGHT-001

Base: `167f108b3871c8496dd55acca6f351b07a2a4e4c`

| Stage | Commit | Result |
| --- | --- | --- |
| N1 authority hardening | `65e5a26` | Software pass. History and root checks sit inside the prepare transaction. A reserved match rejects a generic root. Cancel is exact and pre-lock only. Activation is not capture admission. D1 stays false. |
| N3 local goal journal | `69ff75e` | Software pass. Append, replay, conflict, torn tail, and uncertain retry behave as specified. The success label is local and uncertified. |
| N4 local test score | `e284aa7` | Software pass for the reducer and the existing button labels. `LOCAL TEST` uses the detail slot when it fits. No Bip 6 touch check. No claim that the two-second jump is absent on a device. |
| N2 provision messages | `4763cc6` | `HARDWARE GATE PENDING`. Codec, installation UUID, and file readback pass in unit tests. No Side Service and no paired Bip 6. A simulated exchange is not a physical pass. |
| N5 gap matrix | `71d3c6b` | Review only. Writers for cards and substitutions stay off. |
| N6 verification | this commit | See commands below. |

## Commands

`npm test` in `apps/forref_watch_zepp` completed with 208 tests and 0 failed before the diagnostic log lines. After `FORREF_RECOVERY` and `FORREF_D1` were added, `node --test test/goal_journal.test.js test/local_test_score.test.js test/provision_transport.test.js` completed with 19 tests and 0 failed. Those log lines do not change outcomes.

`./tool/verify_cloud.sh` from the repository root exited 0. The log records pass for cloud bootstrap, `forref_match_core` analyze and test (401 tests), `forref_match_persistence` analyze and test (98 tests), and `apps/referee_phone` analyze and test.

## Acceptance

`LEVEL 1 — SOFTWARE COMPLETE` for provisioning admission, the local goal journal, and score rebuilding from that journal in deterministic tests.

`LEVEL 2 — PHYSICAL FUNCTIONAL PASS` was not achieved. No Bip 6 run.

`LEVEL 3 — OFFICIAL RECORDING CERTIFIED` was not achieved. D1 is uncertified and the watch journal is not Saved.

## Working in software

- Phone reservation refuses a conflicting history and a conflicting root inside the transaction.
- The same provision document can be retried. A different document is refused.
- A prepared reservation can be cancelled before the lock. The lock cannot be cancelled back into phone authority.
- A goal envelope matches the Dart GOAL fields.
- The same capture intent does not add a second goal. A different team on that intent conflicts.
- A torn or unreadable journal does not become 0–0.
- An activated empty journal is local-test 0–0 with `knownScore` false.
- HOME then AWAY goals rebuild 1–0 then 1–1, including after a new journal object reads the same store.

## Simulated only

- Installation UUID persistence, message readback, and activation retry. No radio.
- File-adapter short write. The adapter is an injected filesystem, not Zepp hardware.
- App recreation. Tests construct a new journal object over the same memory store. That is not a device process kill and not a power cut.
- The live page reads a context file. Nothing on the device writes that file, because no page receives the provision messages.

## Certification blockers

- Watch storage has no certified D1 barrier.
- No physical provision or goal was recorded.
- No `.zab`, QR, or install URL was produced.
- Participant provisioning, reason codes, and substitution eligibility remain `HUMAN GATE PENDING — CONTRACT REQUIRED`.
