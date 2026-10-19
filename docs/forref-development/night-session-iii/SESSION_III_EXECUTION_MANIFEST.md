# Night Session III execution manifest

Status of this file: RECORD

## Execution base

SESSION_III_EXECUTION_BASE_SHA: `0c691a8b7d6f76e044ef91709150b4cede9ac6d8`

PRODUCTION AUTHORITY BASELINE: `39a676b25682e2b6930b6d4f7f02340b55ae01a8`

`0c691a8` descends from `39a676b`. The library diff `39a676b..0c691a8` under `packages/**/lib` and `apps/**/lib` is empty. That range is the Phase II handoff record.

BRANCH: `cursor/forref-night-phase2-30fd` at the lock. Implementation continues on `cursor/forref-night-hf-prototype-30fd`.

## Bank DAG

```
N24 baseline
  N25 BANK H research prototype isolation
  N26 BANK I V2 interaction state
  N27 BANK K recovery evidence          (investigative, no production recovery)
N28 BANK J final-action safety          after H and I
N29 BANK L scenarios and instrumentation after H and I
N30 BANK M human validation pack        documents, no human run
```

## Bridge DAG

```
BRIDGE 1 prototype ↔ state             after H and I
BRIDGE 2 state ↔ final-action safety   after I and J
BRIDGE 3 state ↔ recovery evidence     after I and K
BRIDGE 4 prototype ↔ instrumentation   after H and L
BRIDGE 5 instrument ↔ validation pack  after L and M
N36 saboteur
N37 verify_cloud plus research suites
N38 handoff
```

## Protected production paths

Do not edit:

- `packages/forref_match_core/lib/**`
- `packages/forref_match_persistence/lib/**`
- `packages/match_core/**`
- `apps/referee_phone/lib/**`
- watch trees
- injury semantics

A test-only probe under `packages/forref_match_persistence/test/` may read the existing store. It must not change store behavior.

## Research paths

- `research/hf_v2/` — pure Dart research instrument. No Flutter. No `forref_match_persistence`. No `forref_match_core`.
- `research/hf_prototype/` — Flutter research shell. Depends only on Flutter and `hf_v2`. Not registered in the root pub workspace. Not a route in the production phone app.
- `docs/forref-development/night-session-iii/`

## File ownership

| Owner | Paths |
| --- | --- |
| Research instrument | `research/hf_v2/**` |
| Research shell | `research/hf_prototype/**` |
| Recovery probe | `packages/forref_match_persistence/test/research/**` |
| Session docs | `docs/forref-development/night-session-iii/**` |
| Ledger line | `docs/forref-development/PROGRAM_LEDGER.md` |

One writer for each path. Production libraries have no writer this session.

## Test plan

- `research/hf_v2`: isolation, state invariants, final-action attacks, scenarios, bridges, recovery labels.
- `research/hf_prototype`: launch, research banner, spatial gap, rebuild, operator route off the capture column.
- Persistence probe: reopen after close, same-intent retry, known D1 failure. No OS-kill claim.
- `./tool/verify_cloud.sh` for Match Core, persistence, and phone. Research suites run beside it because they are outside the workspace.

## Stop conditions

Stop a path on production leakage, accidental successor authority, false certainty, team identity carry-over, OUT/IN reversal, automatic SEND_OFF, scope bleed, or a production recovery promise. Do not open Foundation or domain questions that are already frozen. Do not add a second Match Memory.

## Expected morning output

A research instrument with deterministic state, fresh-input safety, a truthful recovery map, 19 scenarios, and a moderator pack. Founder pilot is not run. Phone cutover stays HOLD. Production engineering stays unauthorized.

## Completion record

N24_SHA: `320ceab9c661e8b81e6dfb7ac93a9e288ea0db09`

BANK_H_SHA: `1d1bee95c8ae9467ec88dcc92ed87df2120eaac0`

BANK_I_SHA: `b8bf57d45d6812f9659d1945c64e0e53d7b41bc4`

BANK_J_SHA: `956809dbbb2624d394e46f8db604e42f2d4f537a`

BANK_K_SHA: `ef8df4844fa0d87a0d0fb238d29cfc9920b0d677`

BANK_L_SHA: `37f8fb37c4bd046d7a51c7f6871192a916616e3c`

BANK_M_SHA: `1d1bee95c8ae9467ec88dcc92ed87df2120eaac0`

BRIDGE_1_SHA: `1d1bee95c8ae9467ec88dcc92ed87df2120eaac0`

BRIDGE_2_SHA: `b8bf57d45d6812f9659d1945c64e0e53d7b41bc4`

BRIDGE_3_SHA: `1d1bee95c8ae9467ec88dcc92ed87df2120eaac0`

BRIDGE_4_SHA: `37f8fb37c4bd046d7a51c7f6871192a916616e3c`

BRIDGE_5_SHA: `1d1bee95c8ae9467ec88dcc92ed87df2120eaac0`

The in-flight identity repair is `b8bf57d45d6812f9659d1945c64e0e53d7b41bc4`. The saboteur attacks are `9a3becc640bd54485b457c3d3c17ef045d904491`. Production libraries were not edited. The morning record is [SESSION_III_HANDOFF.md](SESSION_III_HANDOFF.md).
