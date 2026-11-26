# EVREC-A1 test report

| Suite | Result |
| --- | --- |
| `packages/forref_match_core` `dart test test/watch_provision_v1_test.dart` | 13 passed |
| `apps/forref_watch_zepp` `npm test` | 183 passed, 0 failed |
| `apps/referee_phone` `flutter test test/watch_provision_a1_test.dart` | 2 passed |
| `dart analyze` on the new provision library and the phone boundary | no issues |

Cross-runtime fixture: `packages/forref_match_core/test/fixtures/watch_provision_v1.json`.

Content hash: `f5be36536b31727a4be1ad177faacd679aefa9bc933ae5dd96d707a7526a5a8a`.

SHA-256("abc") matches `ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad` in both runtimes.

D1: NOT CERTIFIED. Flutter-to-Zepp transport: NOT PRESENT.
