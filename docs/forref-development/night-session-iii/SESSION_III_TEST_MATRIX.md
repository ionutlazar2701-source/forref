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

`./tool/verify_cloud.sh` counts are recorded in the handoff after that run.

The research packages are outside the root pub workspace, so the phone suite does not launch this prototype.
