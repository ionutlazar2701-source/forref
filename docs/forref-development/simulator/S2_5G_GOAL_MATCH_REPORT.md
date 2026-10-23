# S2.5G — Goal scoring and Match Report

## Purpose

Deliver a referee-visible vertical slice in Simulator Lab:

Live → Capture → Goal → team → scorer → Record Goal → updated live score → Match Report entry.

This is research product validation only. It is not production D1 and not Match Memory.

## Research semantic delta

Production Match Core Goal (V1) establishes scoring team only. This research slice additionally captures:

- scorer participant id
- match time label at activation (deterministic match clock, not wall clock)
- action origin trace

Production `packages/forref_match_core` was not modified.

## Goal flow

`WatchRoute.goalFlow` with explicit Home/Away team selection before scorer list. Scorers are filtered to the selected team. Final activation freezes team, scorer, and match time in the shared frozen-command path.

## Temporal rule

Match time comes from `ResearchInstrument.matchElapsedSeconds` formatted as `MM:SS`. Time is captured at Goal activation. Later clock advances do not rewrite a frozen Goal command.

If `matchClockAvailable` is false, final Goal record is blocked.

## Score rule

Score is projected from established `SavedGoal` rows only. Widgets do not increment score locally.

## Match Report rule

`MatchReportPresentation` is referee-facing established events only (Goal today). Event Journal remains engineering trace. Entries sort by established sequence (chronological).

## Failure semantics

- Success: `SIMULATED SAVED — not production D1` → goal established, score and report update.
- Known failure: score and report unchanged.
- Unknown: no established goal; report does not claim success.

## Tests

`research/hf_prototype/test/s2_5g_goal_match_report_test.dart` covers G1–G11 and a founder-style widget journey.

## Windows manual gate

Founder runs SimLab on Windows with scenario `s20GoalMatchReport` (via Match Builder apply or paired fixture load):

1. Live shows `0 – 0` and a non-zero match clock after optional clock advance.
2. Record Home `#9 Popescu` → Live `1 – 0`, Match Report shows Goal with captured time.
3. Record Away `#11` → Live `1 – 1`, report shows two Goals in order.
4. Known failure and unknown outcome scenarios leave score/report unchanged.

## Known limitations

- Discipline events are not yet in Match Report (Yellow next slice).
- Match clock advance is a research operator intent, not a live running timer UI.
- No native watch or production sync.

## Production boundary

No changes under `packages/forref_match_core`, `packages/forref_match_persistence`, `packages/match_core`, or `apps/referee_phone`.
