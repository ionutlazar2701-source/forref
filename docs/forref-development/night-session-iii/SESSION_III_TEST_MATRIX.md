# Night Session III test matrix

Status of this file: RECORD

| Suite | What it locks |
| --- | --- |
| `research/hf_v2/test/isolation_test.dart` | No production imports. Reset. Simulated saved is labeled as not D1. |
| `research/hf_v2/test/interaction_state_test.dart` | Y2, send-off, substitution pre-commit, team invalidation, scope, save not verified. |
| `research/hf_v2/test/final_action_safety_test.dart` | Attacks A–I, selection carry-over, visible is not activated, regions do not overlap. |
| `research/hf_v2/test/scenario_and_bridge_test.dart` | 19 core scenarios plus variants, log on/off, throwing sink, history kept, roles stable. |
| `research/hf_prototype/test/research_shell_test.dart` | Launch banner, repeat tap, rebuild, Home 14, operator panel, phone router isolation. |
| `packages/forref_match_persistence/test/research/session_iii_recovery_probe_test.dart` | File reopen, same intent, known failure, missing row is not a failure object. |
| `research/hf_v2/test/adversarial/session_iii_saboteur_attack_test.dart` | Cross-bank attacks, including an in-flight command that must not follow later edits. |

Executed on this session, after the activation snapshot:

| Suite | Result |
| --- | --- |
| `research/hf_v2` `dart analyze` | No issues found |
| `research/hf_v2` `dart test` | 48 passed. Isolation 3, state 13, safety 14, scenarios/bridges 6, saboteur 12. |
| `research/hf_prototype` `flutter analyze` | No issues found |
| `research/hf_prototype` `flutter test` | 8 passed |
| `./tool/verify_cloud.sh` | PASSED. Exit 0. Core 347, persistence 92, phone 125. |

`tool/verify_cloud.sh` and `tool/cloud_bootstrap.sh` are stored as mode 644. The passing run set the executable bit in the workspace only. That mode change is not part of the session commit. The research packages are outside the root pub workspace, so the cloud script does not launch this prototype. CI is not claimed.
