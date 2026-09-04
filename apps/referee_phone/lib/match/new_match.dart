import 'package:match_core/match_core.dart';

import 'client_ids.dart';

Match newLocalMatch(DateTime now) {
  final utc = now.toUtc();
  final local = now.toLocal();
  final date =
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
  return Match(
    matchId: clientId(),
    status: MatchStatus.setup,
    createdAt: utc,
    updatedAt: utc,
    date: date,
    teams: Teams(
      home: Team(teamId: clientId()),
      away: Team(teamId: clientId()),
    ),
    settings: const MatchSettings(halfDurationSeconds: 2700),
    periods: defaultMatchPeriods(),
    currentState: const MatchState(
      periodId: PeriodId.firstHalf,
      clockRunning: false,
      elapsedSeconds: 0,
    ),
    score: const Score(home: 0, away: 0),
  );
}

String formatMatchClock(int elapsedSeconds) {
  final safe = elapsedSeconds < 0 ? 0 : elapsedSeconds;
  final minutes = safe ~/ 60;
  final seconds = safe % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
