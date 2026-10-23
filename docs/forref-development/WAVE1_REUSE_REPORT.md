# WAVE 1 historical reuse report

Parent inspected: `5772671a9674e00c372268047d5f54073610af22`.

No historical branch is merged. None of these SHAs is an ancestor of the accepted Foundation SHA.

| SHA | Subject | Class | Why |
| --- | --- | --- | --- |
| `3c2a37dada8560765c45597975b67edd8d422448` (PR #2) | Freeze GOAL as a main-referee determination. | PARTIAL REUSE | Useful concept: a GOAL semantic on the v1 registry, a Goal payload, and an admission type. Reject the payload: it uses `scoringSide` (HOME/AWAY), requires `period`, and carries optional player identity. Reject `GoalMatchProjection.empty`, which sets `homeScore: 0` and `awayScore: 0`. |
| `4e602485c2a9bb85754b7cdb060ac16ac1318aed` (PR #3) | Cut Live Match Goal capture over to Match Memory. | PARTIAL REUSE | Useful concept: the phone boundary can call Match Memory for Goal. Reject wholesale reuse. The line still sits on the conflicting score projection, and red and substitution stayed on the legacy writer. Do not copy a legacy Goal fallback. |
| `3c07f1a09d4cd6272acc04acd8113fccfff736ff` (PR #4) | Consolidate Goal/score read surfaces onto GoalMatchProjection. | REJECT | The read surface is built on the integer 0–0 empty projection. That contradicts UNKNOWN SCORE ≠ KNOWN 0–0. |

No historical SHA defines `MatchTeamId`. Stable team identity is new, and it is the smallest binding, not a participant registry.
