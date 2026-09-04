import '../enums/enums.dart';
import '../models/match.dart';
import '../models/match_state.dart';
import '../models/period.dart';

/// Reconstruct elapsed time from [MatchState]. No UI timer.
final class MatchClock {
  const MatchClock();

  /// `elapsedSeconds + floor((now - runningSince) / 1000)` while running.
  int currentElapsed(MatchState state, DateTime now) {
    if (!state.clockRunning || state.runningSince == null) {
      return state.elapsedSeconds;
    }
    final deltaMs =
        now.toUtc().difference(state.runningSince!.toUtc()).inMilliseconds;
    if (deltaMs <= 0) {
      return state.elapsedSeconds;
    }
    return state.elapsedSeconds + deltaMs ~/ 1000;
  }

  MatchState onPause(MatchState state, DateTime now) {
    if (!state.clockRunning) {
      return state.copyWith(clearRunningSince: true);
    }
    return state.copyWith(
      elapsedSeconds: currentElapsed(state, now),
      clockRunning: false,
      clearRunningSince: true,
    );
  }

  MatchState onResume(MatchState state, DateTime now) {
    if (state.clockRunning) {
      return state;
    }
    return state.copyWith(
      clockRunning: true,
      runningSince: now.toUtc(),
    );
  }

  /// Kick-off from READY only. Starts 1H at 00:00.
  Match applyKickOff(Match match, DateTime now) {
    if (match.status != MatchStatus.ready) {
      throw StateError(
        'Kick-off requires status ready, was ${match.status.jsonValue}',
      );
    }
    final utc = now.toUtc();
    final periods = _periodsForKickOff(match.periods, utc);
    return match.copyWith(
      status: MatchStatus.live,
      updatedAt: utc,
      periods: periods,
      currentState: MatchState(
        periodId: PeriodId.firstHalf,
        clockRunning: true,
        elapsedSeconds: 0,
        runningSince: utc,
        addedTimeSeconds: 0,
      ),
    );
  }

  List<Period> _periodsForKickOff(List<Period> existing, DateTime utc) {
    final base = existing.isEmpty ? defaultMatchPeriods() : existing;
    return [
      for (final period in base)
        if (period.id == PeriodId.firstHalf)
          period.copyWith(
            status: PeriodStatus.active,
            startedAt: utc,
          )
        else
          period,
    ];
  }
}
