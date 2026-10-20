# Subagent charters actually issued

Delegation happened. Models below are what the agents reported, not a label substituted after the fact.

Isolated worktrees via the best-of-n runner. Read-only review via a general-purpose agent. None were told to merge to `main` or open a PR.

## 1. Score trust — Grok 4.7

- Agent id: `bc-8b076f0f-f713-5c29-b98b-978114f5d144`
- Requested model: `grok-4.7-high`. Reported model: Grok 4.7
- Branch: `cursor/forref-wave1-score-trust-30fd` @ `5e08b2ab144d0cc145aeb0afba4bf781dfc75e43`
- Objective: lock existing fail-closed score behavior. Do not invent a numeral or a Score Projection Trust freeze.
- Ownership: `packages/forref_match_core/test/adversarial/score_trust_fail_closed_test.dart`, `docs/forref-execution/evidence/score-trust/REPORT.md`
- Forbidden: all `lib/`, pubspecs, phone app, persistence, legacy package
- Acceptance: tests pass on unchanged production code, or a failing test is kept and marked HOLD
- Reported result: 9 new tests passed; full core suite 138 passed on that branch alone

## 2. Temporal attacks — Grok 4.7

- Agent id: `bc-84d9f66e-d22a-555b-9864-aa4117cc79e9`
- Requested model: `grok-4.7-high`. Reported model: Grok 4.7
- Branch: `cursor/forref-wave1-temporal-attack-30fd` @ `1e6b1f12ede7977dc6ca83387f31c014a08048da`
- Objective: attack false exact elapsed and false period-end. Do not certify device clocks.
- Ownership: `temporal_recovery_attack_test.dart`, `evidence/temporal/REPORT.md`
- Forbidden: `lib/` and any persistence or UI change
- Reported result: 25 new tests passed; no false exact elapsed; no false period end. LOCAL GATE REQUIRED for hardware clocks

## 3. Disciplinary gap — Grok 4.7

- Agent id: `bc-11401625-31bf-5d03-b895-3d3adbc7c6f1`
- Requested model: `grok-4.7-high`. Reported model: Grok 4.7
- Branch: `cursor/forref-wave1-disciplinary-gap-30fd` @ `bc047369f6535b179bc69aec1ff0f421c98b5a2a`
- Objective: prove v1 records do not trust disciplinary projection, unregistered wires stay unsupported, and two legacy yellows do not append a red. Do not add Yellow/Red/Sub workflows.
- Ownership: `disciplinary_scope_fail_closed_test.dart`, `packages/match_core/test/events/no_automatic_red_test.dart`, `evidence/disciplinary/REPORT.md`
- Reported result: two yellows stayed yellow; score stayed 0–0; shootout scope absent

## 4. Referee harness — Composer 2.5

- Agent id: `bc-8acc4910-e9e5-581a-8100-fe25158b4794`
- Requested model: `composer-2.5`. Reported model: composer-2.5
- Branch: `cursor/forref-wave1-referee-harness-30fd` @ `ea356c29c51c7ffc380aa47da578f33a34e36fd0`
- Objective: standalone pure-Dart trial harness. No Match Core import. No human results. Thresholds unregistered. Cautions not formal-002D-scorable. No UI.
- Ownership: `research/live_core_a/**` only, not added to the workspace pubspec
- Reported result: `dart test` 9 passed, `dart analyze` clean

## 5. Geometry harness — Composer

- Agent id: `bc-954872b2-e56b-561b-8ff9-f54cce54c52f`
- Requested model: `composer-2.5`. Reported model: Composer
- Branch: `cursor/forref-wave1-geometry-harness-30fd` @ `479957e02d26936e16f774fe17902e59d10fa6d6`
- Objective: pure geometry checker. No `PHYSICAL_PASS`. Candidate watches are uncertified declarations. Empty measured matrix cannot become ready.
- Ownership: `research/a_physical/**`
- Reported result: 11 tests passed on that commit. Later review found a viewport fail-open. Fixed on the integration branch, not by rewriting history.

## 6. Independent review — Grok 4.7

- Agent id: `bc-2d7266f0-e503-593c-a561-468caf5c4483`
- Requested model: `grok-4.7-high`. Reported as the review narrative from that agent.
- Mode: read-only. No branch, no commit.
- Verdict: four branches integration-ready; geometry HOLD until a finite viewport is required. Also flagged a tautological `isNot(isA<int>())` in the score test.
- Those two findings were fixed in `6b53a8c` and `00485fb` before the documentation commit.

## Not launched

Goal, Yellow, Red, Substitution, watch integration, 002D closure, C screen redesign, and hardware certification were not delegated. Their prompts in the research document remain unauthorized until the gates in `DEPENDENCY_GRAPH.md` close.
