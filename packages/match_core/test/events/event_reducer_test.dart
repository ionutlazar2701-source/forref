import 'package:match_core/match_core.dart';
import 'package:test/test.dart';

void main() {
  const factory = EventFactory();
  const reducer = EventReducer();
  final now = DateTime.utc(2026, 9, 3, 18);

  Match live() => Match(
        matchId: 'm',
        status: MatchStatus.live,
        createdAt: now,
        updatedAt: now,
        date: '2026-09-03',
        teams: const Teams(
          home: Team(teamId: 'h'),
          away: Team(teamId: 'a'),
        ),
        settings: const MatchSettings(halfDurationSeconds: 2700),
        currentState: const MatchState(
          periodId: PeriodId.firstHalf,
          clockRunning: true,
          elapsedSeconds: 0,
        ),
        score: const Score(home: 0, away: 0),
      );

  test('new goal updates derived score', () {
    final event = factory.create(
      eventId: 'g1',
      matchId: 'm',
      type: EventType.goal,
      periodId: PeriodId.firstHalf,
      matchTime: 10,
      now: now,
      data: const EventData(
        teamId: 'h',
        player: PlayerRef(playerId: 'p', isUnknown: false),
      ),
    );
    final next = reducer.applyNewEvent(live(), event);
    expect(next.events, hasLength(1));
    expect(next.score.home, 1);
    expect(next.score.away, 0);
  });

  test('goal to yellow rebuilds score and appends history', () {
    final goal = factory.create(
      eventId: 'g1',
      matchId: 'm',
      type: EventType.goal,
      periodId: PeriodId.firstHalf,
      matchTime: 10,
      now: now,
      data: const EventData(
        teamId: 'h',
        player: PlayerRef(playerId: 'p', isUnknown: false),
      ),
    );
    var match = reducer.applyNewEvent(live(), goal);
    expect(match.score.home, 1);

    final asYellow = goal.copyWith(
      type: EventType.yellowCard,
      data: goal.data,
    );
    match = reducer.applyEventUpdate(
      match,
      asYellow,
      historyId: 'hist-1',
      now: now.add(const Duration(minutes: 1)),
    );
    expect(match.events.single.type, EventType.yellowCard);
    expect(match.events.single.eventId, 'g1');
    expect(match.score.home, 0);
    expect(match.history, hasLength(1));
    expect(match.history.single.previousValue['type'], 'goal');
    expect(match.history.single.newValue['type'], 'yellow_card');
  });

  test('undo last save removes the event and rebuilds score', () {
    final goal = factory.create(
      eventId: 'g1',
      matchId: 'm',
      type: EventType.goal,
      periodId: PeriodId.firstHalf,
      matchTime: 10,
      now: now,
      data: const EventData(
        teamId: 'h',
        player: PlayerRef(playerId: 'p', isUnknown: false),
      ),
    );
    var match = reducer.applyNewEvent(live(), goal);
    expect(match.score.home, 1);
    match = reducer.undoNewEvent(
      match,
      eventId: 'g1',
      historyId: 'undo-1',
      now: now.add(const Duration(seconds: 3)),
    );
    expect(match.events, isEmpty);
    expect(match.score.home, 0);
    expect(match.history.single.action, HistoryAction.undo);
  });
}
