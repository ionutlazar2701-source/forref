# MATCH REPORT AUTHORITY BRIDGE 001

Verdict: **PASS** for the bounded slice. The phone live screen and the Zepp client are not cut over. That is the next gate, not a failure of this projection.

## What landed

`projectMatchReport` in `packages/forref_match_core` rebuilds a disposable report from committed records. Score numerals come only from `DeterministicMatchProjector`. Goal, Yellow, send-off, and substitution lines come from the existing effective resolvers. Temporal lines carry the transition code and period identity. Every line's time fact is `exactMatchTimeUnavailable`. There is no minute field.

Classifications stay distinct:

- known effective rows
- conflict when competing corrections disagree
- unavailable when a correction target or a second-caution dependency is missing
- unverified when temporal trust is untrusted
- unsupported structured payloads are listed and are not goals

The phone `MatchApplicationBoundary` commits Yellow, direct send-off, second-caution send-off, and substitution through the same `SqliteDurableMatchStore` as Goal and Kick-off. `readMatchReport` reloads that store. An unreadable quarantine returns `MatchReportReadiness.unreadable` and `ScoreUnavailable`. Legacy Drift is not written.

## Proof

- `packages/forref_match_core/test/match_report_projection_test.dart` — 6 tests. Shuffled input and a shifted `recordedAt` rebuild the same report. A goal without a completeness proof does not become a score.
- `apps/referee_phone/test/match_report_bridge_test.dart` — 3 tests. Commit success, report, process-style reopen of the same SQLite file, identical report. A forced pre-commit abort leaves no Yellow line. A substitution without team bindings is not saved. The legacy match events stay empty and the legacy score stays 0–0.

`./tool/verify_cloud.sh` exit 0. Match Core analyze plus 383 tests. Persistence analyze plus 92 tests. Phone analyze plus 128 tests.

## Outstanding gates

- Human: LOTG reason schema. See `LOTG_REASON_FOLLOW_UP.md`.
- Product cutover: phone summary still opens legacy `MatchSession`. Do not dual-write it.
- Zepp: still prototype selection and `LocalStorage`. See `ZEPP_CUTOVER.md`.
- No hardware, field, or signing certification. Local SQLite D1 in this suite is the certified adapter's commit result, not a watch or phone field trial.

PR #45 remains unmerged and is not the base of this branch.
