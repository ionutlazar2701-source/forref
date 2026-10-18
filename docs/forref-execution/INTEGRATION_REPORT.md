# Integration report

Branch: `cursor/forref-wave1-integration-30fd`  
Code tip before this documentation commit: `00485fb`  
Parent of the wave: `919c9062d607f0af255ad368b8c6cb2658d6c85a`

The integration branch was created from the disciplinary tip (`bc04736`), which was the workspace HEAD after that agent finished, then merged the other four branches. Content from all five is present. It adds two follow-up commits:

| SHA | Change |
| --- | --- |
| `6b53a8c` | Finite positive viewport required before `readyForPhysicalGate` |
| `00485fb` | Removed tautological score-trust `isA<int>` assertion |

`main` was not updated.

## Branch status

| Branch | Tip | Integration |
| --- | --- | --- |
| score-trust | `5e08b2a` | Merged. Ready as tests only |
| temporal-attack | `1e6b1f1` | Merged. Ready as tests only |
| disciplinary-gap | `bc04736` | Merged. Ready as tests only |
| referee-harness | `ea356c2` | Merged. Ready as non-production research |
| geometry-harness | `479957e` | Merged, then corrected by `6b53a8c`. Ready as non-production research |
| integration | `00485fb` plus docs | Repository verification passed. Not a watch release |

## Tests run on the integrated tree

| Command | Result |
| --- | --- |
| `research/a_physical`: `dart analyze` && `dart test` | No issues. 12 passed |
| `research/live_core_a`: `dart analyze` && `dart test` | No issues. 9 passed |
| `packages/forref_match_core`: `dart test test/adversarial` | 41 passed |
| `packages/forref_match_core`: `dart test` | 170 passed |
| `packages/match_core`: `dart test` | 35 passed |
| `./tool/verify_cloud.sh` | PASSED (core, persistence, phone analyze + test) |

`verify_cloud.sh` does not execute `packages/match_core` or `research/**`. Those were run directly. Log: cloud output captured during the run; package log at the agent artifact `wave1_verification.log`.

Scripts are mode `100644` in git. The cloud run used a local executable bit that was not committed.

## Review findings

| Finding | Disposition |
| --- | --- |
| Null / one-sided / NaN / infinite viewport could return `readyForPhysicalGate` | Fixed in `6b53a8c`. New test covers those inputs. Still not hardware certification |
| `expect(score.trust, isNot(isA<int>()))` cannot fail | Removed in `00485fb`. Untrusted assertion remains |
| Empty participant-id list test does not stop a future bug that invents trials from ids | Accepted. Current export returns stored trials only. Noted in the risk register |
| No production `lib/` edits on the five branches | Confirmed by diff |

## Gates

| Package | IMPLEMENTATION | TEST EVIDENCE | DOMAIN | ARCHITECTURE | HUMAN FACTORS | RELIABILITY | INTEGRATION |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Score fail-closed tests | NOT APPLICABLE | PASS | REQUIRED for any numeral | NOT APPLICABLE | NOT APPLICABLE | PASS for fail-closed | READY as tests |
| Temporal attacks | NOT APPLICABLE | PASS | PASS for display-vs-period-end | PASS | NOT APPLICABLE | LOCAL GATE REQUIRED for device clocks | READY as tests |
| Disciplinary tests | NOT APPLICABLE | PASS | REQUIRED before Yellow/Red/Sub | PASS | NOT APPLICABLE | PASS for no auto-red on the tested path | READY as tests |
| `research/live_core_a` | PASS as harness | PASS | NOT APPLICABLE | NOT APPLICABLE | REQUIRED | PASS as instrumentation | READY as research, not product |
| `research/a_physical` | PASS as checker after fix | PASS | NOT APPLICABLE | NOT APPLICABLE | REQUIRED | LOCAL GATE REQUIRED | READY as research, not product |
| Watch capture foundation | NOT STARTED | INCOMPLETE | REQUIRED | REQUIRED | REQUIRED | REQUIRED | BLOCKED |
| 002D-1B | NOT STARTED | HOLD | REQUIRED | NOT APPLICABLE | REQUIRED | NOT APPLICABLE | BLOCKED |

## Not claimed

No physical watch was operated. No referee was tested. No power-loss certification. No production score. No Capture Foundation freeze. No Saved acknowledgement was simulated.
