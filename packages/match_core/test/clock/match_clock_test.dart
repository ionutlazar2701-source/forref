import 'package:match_core/match_core.dart';
import 'package:test/test.dart';

void main() {
  const clock = MatchClock();

  final runningSince = DateTime.utc(2026, 9, 3, 18, 10);

  MatchState liveAt(DateTime since) => MatchState(
        periodId: PeriodId.firstHalf,
        clockRunning: true,
        elapsedSeconds: 642,
        runningSince: since,
      );

  test('running clock adds floor seconds since checkpoint', () {
    final now = DateTime.utc(2026, 9, 3, 18, 10, 42);
    expect(clock.currentElapsed(liveAt(runningSince), now), 684);
  });

  test('paused clock returns elapsedSeconds', () {
    const paused = MatchState(
      periodId: PeriodId.firstHalf,
      clockRunning: false,
      elapsedSeconds: 642,
    );
    expect(
      clock.currentElapsed(paused, DateTime.utc(2026, 9, 3, 18, 20)),
      642,
    );
  });

  test('pause checkpoints elapsed and clears runningSince', () {
    final now = DateTime.utc(2026, 9, 3, 18, 10, 42);
    final paused = clock.onPause(liveAt(runningSince), now);
    expect(paused.clockRunning, isFalse);
    expect(paused.runningSince, isNull);
    expect(paused.elapsedSeconds, 684);
  });

  test('resume sets runningSince and keeps elapsed', () {
    const paused = MatchState(
      periodId: PeriodId.firstHalf,
      clockRunning: false,
      elapsedSeconds: 684,
    );
    final now = DateTime.utc(2026, 9, 3, 18, 11);
    final resumed = clock.onResume(paused, now);
    expect(resumed.clockRunning, isTrue);
    expect(resumed.runningSince, now);
    expect(resumed.elapsedSeconds, 684);
  });

  test('kick-off from READY starts 1H at zero', () {
    final now = DateTime.utc(2026, 9, 3, 18);
    final live = clock.applyKickOff(_readyMatch(), now);
    expect(live.status, MatchStatus.live);
    expect(live.currentState.clockRunning, isTrue);
    expect(live.currentState.elapsedSeconds, 0);
    expect(live.currentState.runningSince, now);
    expect(live.currentState.periodId, PeriodId.firstHalf);
    expect(live.periods.first.status, PeriodStatus.active);
    expect(live.periods.first.startedAt, now);
  });

  test('kick-off from LIVE is rejected', () {
    expect(
      () => clock.applyKickOff(
        _readyMatch().copyWith(status: MatchStatus.live),
        DateTime.utc(2026, 9, 3),
      ),
      throwsStateError,
    );
  });
}

Match _readyMatch() {
  return Match(
    matchId: 'm',
    status: MatchStatus.ready,
    createdAt: DateTime.utc(2026, 9, 3, 17, 50),
    updatedAt: DateTime.utc(2026, 9, 3, 17, 50),
    date: '2026-09-03',
    teams: const Teams(
      home: Team(teamId: 'h'),
      away: Team(teamId: 'a'),
    ),
    settings: const MatchSettings(halfDurationSeconds: 2700),
    currentState: const MatchState(
      periodId: PeriodId.firstHalf,
      clockRunning: false,
      elapsedSeconds: 0,
    ),
    score: const Score(home: 0, away: 0),
  );
}
