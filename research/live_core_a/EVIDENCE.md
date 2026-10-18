# EVIDENCE — live_core_a harness

## Model

Implementation model recorded for audit: **composer-2.5** (Cursor agent session).

## Human participants

**None.** This harness was implemented and verified by automated tests only. No referee or other human participant performance is claimed.

## Thresholds

**UNREGISTERED** — see `InstrumentAThresholds` in `lib/src/thresholds.dart`.

## 002D Recall

**HOLD / UNAVAILABLE** — `research/watch_core_r1` and commit `fda5af6` are not in this repository. Cautions trials are not formal 002D-scorable.

## Verification commands

From `research/live_core_a`:

- `dart pub get`
- `dart test`
- `dart analyze` (when SDK provides analyzer)

Results are captured in the agent run log for this branch.

## Gates (research instrumentation)

| Gate | Status |
| --- | --- |
| IMPLEMENTATION | See branch `cursor/forref-wave1-referee-harness-30fd` under `research/live_core_a/**` only |
| TEST EVIDENCE | `dart test` in package directory |
| DOMAIN | No Match Memory writes; no production package imports |
| HUMAN FACTORS | **REQUIRED** — no field study executed; do not infer UX approval |
| RELIABILITY | Deterministic order generator; JSON round-trip tests |
| INTEGRATION | Standalone package; not in root workspace |
