import 'package:match_core/match_core.dart';
import 'package:test/test.dart';

void main() {
  const scores = ScoreCalculator();

  MatchEvent goal({
    required String teamId,
    bool ownGoal = false,
  }) {
    return MatchEvent(
      eventId: 'g-$teamId-$ownGoal',
      matchId: 'm',
      type: EventType.goal,
      status: EventStatus.complete,
      periodId: PeriodId.firstHalf,
      matchTime: 1,
      createdAt: DateTime.utc(2026, 9, 3),
      updatedAt: DateTime.utc(2026, 9, 3),
      data: EventData(
        teamId: teamId,
        isOwnGoal: ownGoal,
        player: const PlayerRef(playerId: 'p', isUnknown: false),
      ),
    );
  }

  test('empty events are 0-0', () {
    expect(
      scores.fromEvents(const [], homeTeamId: 'h', awayTeamId: 'a'),
      isA<Score>(),
    );
    final score = scores.fromEvents(const [], homeTeamId: 'h', awayTeamId: 'a');
    expect(score.home, 0);
    expect(score.away, 0);
  });

  test('home goal increments home', () {
    final score = scores.fromEvents(
      [goal(teamId: 'h')],
      homeTeamId: 'h',
      awayTeamId: 'a',
    );
    expect(score.home, 1);
    expect(score.away, 0);
  });

  test('own goal by home awards away', () {
    final score = scores.fromEvents(
      [goal(teamId: 'h', ownGoal: true)],
      homeTeamId: 'h',
      awayTeamId: 'a',
    );
    expect(score.home, 0);
    expect(score.away, 1);
  });

  test('cards do not affect score', () {
    final yellow = MatchEvent(
      eventId: 'y',
      matchId: 'm',
      type: EventType.yellowCard,
      status: EventStatus.incomplete,
      periodId: PeriodId.firstHalf,
      matchTime: 2,
      createdAt: DateTime.utc(2026, 9, 3),
      updatedAt: DateTime.utc(2026, 9, 3),
      data: const EventData(
        teamId: 'a',
        player: PlayerRef(isUnknown: true),
      ),
    );
    final score = scores.fromEvents(
      [goal(teamId: 'h'), yellow],
      homeTeamId: 'h',
      awayTeamId: 'a',
    );
    expect(score.home, 1);
    expect(score.away, 0);
  });
}
