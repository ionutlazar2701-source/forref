import 'package:match_core/match_core.dart';
import 'package:test/test.dart';

void main() {
  const lifecycle = MatchLifecycle();
  const validator = EventValidator();
  final t0 = DateTime.utc(2026, 9, 3, 18);

  Match kickOff() => lifecycle.applyKickOff(_readyMatch(), t0);

  test('pause then resume stays on 1H', () {
    final atTen = t0.add(const Duration(minutes: 10));
    var match = lifecycle.applyPause(kickOff(), atTen);
    expect(match.status, MatchStatus.paused);
    expect(match.currentState.clockRunning, isFalse);
    expect(match.currentState.elapsedSeconds, 600);
    expect(match.currentState.periodId, PeriodId.firstHalf);

    match = lifecycle.applyResume(match, atTen.add(const Duration(minutes: 1)));
    expect(match.status, MatchStatus.live);
    expect(match.currentState.periodId, PeriodId.firstHalf);
    expect(match.currentState.elapsedSeconds, 600);
  });

  test('resume from half-time is rejected', () {
    final ht = lifecycle.applyHalfTime(
      kickOff(),
      t0.add(const Duration(minutes: 45)),
    );
    expect(ht.status, MatchStatus.halfTime);
    expect(
      () => lifecycle.applyResume(ht, t0.add(const Duration(minutes: 46))),
      throwsStateError,
    );
  });

  test('half-time then start 2H from 00:00', () {
    var match = lifecycle.applyHalfTime(
      kickOff(),
      t0.add(const Duration(minutes: 45)),
    );
    expect(match.status, MatchStatus.halfTime);
    expect(match.currentState.clockRunning, isFalse);
    expect(match.currentState.elapsedSeconds, 2700);
    expect(
      match.periods.firstWhere((p) => p.id == PeriodId.firstHalf).status,
      PeriodStatus.completed,
    );

    match = lifecycle.applyStartSecondHalf(
      match,
      t0.add(const Duration(minutes: 60)),
    );
    expect(match.status, MatchStatus.live);
    expect(match.currentState.periodId, PeriodId.secondHalf);
    expect(match.currentState.elapsedSeconds, 0);
    expect(match.currentState.clockRunning, isTrue);
    expect(
      match.periods.firstWhere((p) => p.id == PeriodId.penalties).status,
      PeriodStatus.pending,
    );
  });

  test('extra time starts et1 from 2H before full time', () {
    var match = _liveSecondHalf(lifecycle, t0);
    match = lifecycle.setAddedTime(match, 180, t0);
    match = lifecycle.applyStartExtraTime(
      match,
      t0.add(const Duration(minutes: 90)),
    );
    expect(match.status, MatchStatus.live);
    expect(match.currentState.periodId, PeriodId.extraTime1);
    expect(match.currentState.elapsedSeconds, 0);
    expect(
      match.periods.firstWhere((p) => p.id == PeriodId.secondHalf).status,
      PeriodStatus.completed,
    );
    expect(
      match.periods.firstWhere((p) => p.id == PeriodId.penalties).status,
      PeriodStatus.pending,
    );
  });

  test('ET1 half-time then start ET2; pens stay pending', () {
    var match = _liveSecondHalf(lifecycle, t0);
    match = lifecycle.applyStartExtraTime(
      match,
      t0.add(const Duration(minutes: 90)),
    );
    match = lifecycle.applyHalfTime(
      match,
      t0.add(const Duration(minutes: 105)),
    );
    expect(match.status, MatchStatus.halfTime);
    expect(match.currentState.periodId, PeriodId.extraTime1);
    match = lifecycle.applyStartSecondHalf(
      match,
      t0.add(const Duration(minutes: 107)),
    );
    expect(match.status, MatchStatus.live);
    expect(match.currentState.periodId, PeriodId.extraTime2);
    expect(match.currentState.elapsedSeconds, 0);
    expect(
      match.periods.firstWhere((p) => p.id == PeriodId.penalties).status,
      PeriodStatus.pending,
    );
  });

  test('extra time from 1H is rejected', () {
    expect(
      () => lifecycle.applyStartExtraTime(kickOff(), t0),
      throwsStateError,
    );
  });

  test('full time freezes clock and undo restores previous period', () {
    var match = _liveSecondHalf(lifecycle, t0);
    final ftAt = t0.add(const Duration(minutes: 90));
    match = lifecycle.applyFullTime(match, historyId: 'ft-1', now: ftAt);
    expect(match.status, MatchStatus.fullTime);
    expect(match.currentState.clockRunning, isFalse);
    expect(lifecycle.canUndoFullTime(match), isTrue);

    match = lifecycle.undoFullTime(
      match,
      historyId: 'ft-undo',
      now: ftAt.add(const Duration(seconds: 3)),
    );
    expect(match.status, MatchStatus.live);
    expect(match.currentState.periodId, PeriodId.secondHalf);
    expect(match.currentState.clockRunning, isTrue);
    expect(match.currentState.elapsedSeconds, 1800);
    expect(match.history.last.action, HistoryAction.undo);
  });

  test('finish closes the record; undo full time is then rejected', () {
    var match = lifecycle.applyFullTime(
      kickOff(),
      historyId: 'ft-1',
      now: t0.add(const Duration(minutes: 45)),
    );
    match = lifecycle.applyFinish(match, t0.add(const Duration(hours: 2)));
    expect(match.status, MatchStatus.completed);
    expect(
      () => lifecycle.undoFullTime(
        match,
        historyId: 'nope',
        now: t0.add(const Duration(hours: 2)),
      ),
      throwsStateError,
    );
  });

  test('incomplete events do not block full time or finish', () {
    const factory = EventFactory();
    final incomplete = factory.create(
      eventId: 'y1',
      matchId: 'm',
      type: EventType.yellowCard,
      periodId: PeriodId.firstHalf,
      matchTime: 10,
      now: t0,
      data: const EventData(
        teamId: 'h',
        player: PlayerRef(isUnknown: true),
      ),
    );
    var match = const EventReducer().applyNewEvent(kickOff(), incomplete);
    expect(validator.incompleteCount(match.events), 1);
    match = lifecycle.applyFullTime(
      match,
      historyId: 'ft-1',
      now: t0.add(const Duration(minutes: 45)),
    );
    expect(match.status, MatchStatus.fullTime);
    match = lifecycle.applyFinish(match, t0.add(const Duration(hours: 2)));
    expect(match.status, MatchStatus.completed);
  });

  test('added time updates the current period, not a second clock', () {
    final match = lifecycle.setAddedTime(kickOff(), 120, t0);
    expect(match.currentState.addedTimeSeconds, 120);
    expect(
      match.periods.firstWhere((p) => p.id == PeriodId.firstHalf).addedTimeSeconds,
      120,
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

Match _liveSecondHalf(MatchLifecycle lifecycle, DateTime t0) {
  var match = lifecycle.applyKickOff(_readyMatch(), t0);
  match = lifecycle.applyHalfTime(match, t0.add(const Duration(minutes: 45)));
  return lifecycle.applyStartSecondHalf(
    match,
    t0.add(const Duration(minutes: 60)),
  );
}
