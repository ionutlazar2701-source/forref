# EVREC-A1R test report

Simulated store-port and SQLite tests. They are not a Bip 6 run and they are not D1 evidence.

| Suite | Result |
| --- | --- |
| `packages/forref_match_core` `dart test test/watch_provision_v1_test.dart` | 21 passed |
| `apps/forref_watch_zepp` `npm test` | 189 passed, 0 failed |
| `apps/forref_watch_zepp` `node --test test/watch_provision.test.js` | 20 passed |
| `apps/referee_phone` `flutter test test/watch_provision_a1_test.dart` | 4 passed |
| `dart analyze` on the provision library, the phone boundary, and the SQLite store | no issues |

The watch suite covers configuration without activation, a lost activation acknowledgement, restart before and after activation, a changed installation UUID, idempotent activation, and a conflicting activation.

The phone suite covers transport unavailable before the lock, preparation without a root row, a close and reopen after `PHONE_AUTHORITY_LOCKED`, and an existing phone goal that blocks provisioning.

Cross-runtime fixture: `packages/forref_match_core/test/fixtures/watch_provision_v1.json`.

Content hash: `f5be36536b31727a4be1ad177faacd679aefa9bc933ae5dd96d707a7526a5a8a`.

SHA-256("abc") matches `ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad` in both runtimes.

D1: NOT CERTIFIED. Live Flutter-to-Zepp transport: NOT PRESENT. The source branches are recorded in `FEASIBILITY_PROTOCOL.md` and were not cherry-picked.
