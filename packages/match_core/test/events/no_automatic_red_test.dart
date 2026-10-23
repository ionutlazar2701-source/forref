import 'package:match_core/match_core.dart';
import 'package:test/test.dart';

void main() {
  const factory = EventFactory();
  const reducer = EventReducer();
  final now = DateTime.utc(2026, 9, 3, 18);
  const player = PlayerRef(playerId: 'p9', isUnknown: false);
  const data = EventData(teamId: 'h', player: player);

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

  test(
      'two yellow cards for the same player do not append a red or change the score',
      () {
    final first = factory.create(
      eventId: 'y1',
      matchId: 'm',
      type: EventType.yellowCard,
      periodId: PeriodId.firstHalf,
      matchTime: 600,
      now: now,
      data: data,
    );
    final second = factory.create(
      eventId: 'y2',
      matchId: 'm',
      type: EventType.yellowCard,
      periodId: PeriodId.firstHalf,
      matchTime: 1200,
      now: now.add(const Duration(minutes: 10)),
      data: data,
    );

    var match = reducer.applyNewEvent(live(), first);
    match = reducer.applyNewEvent(match, second);

    expect(match.events, hasLength(2));
    expect(
      match.events.map((event) => event.type),
      [EventType.yellowCard, EventType.yellowCard],
    );
    expect(match.events.map((event) => event.eventId), ['y1', 'y2']);
    expect(
      match.events.map((event) => event.data.player?.playerId),
      ['p9', 'p9'],
    );
    expect(
      match.events.where((event) => event.type == EventType.redCard),
      isEmpty,
    );
    expect(match.score.home, 0);
    expect(match.score.away, 0);
    expect(match.history, isEmpty);
  });
}
