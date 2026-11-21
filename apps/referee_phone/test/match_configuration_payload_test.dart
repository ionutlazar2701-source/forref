import 'package:flutter_test/flutter_test.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/officiate/match_configuration_payload.dart';

void main() {
  test('version 1 projects configuration and omits sporting history', () {
    final match = Match(
      matchId: 'match-1',
      status: MatchStatus.live,
      createdAt: DateTime.utc(2026, 11, 21, 10),
      updatedAt: DateTime.utc(2026, 11, 21, 11, 5),
      competition: '  County Cup ',
      venue: '',
      date: '2026-11-21',
      teams: const Teams(
        home: Team(teamId: 'home', name: 'North'),
        away: Team(teamId: 'away', name: 'South'),
      ),
      crew: const Crew(
        referee: CrewMember(name: 'Ionescu'),
        fourthOfficial: CrewMember(name: '  '),
      ),
      settings: const MatchSettings(
        halfDurationSeconds: 2700,
        extraTimeEnabled: true,
        extraTimeHalfDurationSeconds: 900,
      ),
      periods: defaultMatchPeriods(),
      currentState: const MatchState(
        periodId: PeriodId.firstHalf,
        clockRunning: true,
        elapsedSeconds: 120,
      ),
      score: const Score(home: 2, away: 1),
      events: [
        MatchEvent(
          eventId: 'e1',
          matchId: 'match-1',
          type: EventType.goal,
          status: EventStatus.complete,
          periodId: PeriodId.firstHalf,
          matchTime: 40,
          createdAt: DateTime.utc(2026, 11, 21, 11),
          updatedAt: DateTime.utc(2026, 11, 21, 11),
          data: const EventData(teamId: 'home'),
        ),
      ],
    );

    final payload = MatchConfigurationPayload.fromMatch(match);
    final json = payload.toJson();

    expect(json['payloadVersion'], 1);
    expect(json['homeTeamName'], 'North');
    expect(json['awayTeamName'], 'South');
    expect(json['competition'], 'County Cup');
    expect(json['venue'], isNull);
    expect(json['referee'], 'Ionescu');
    expect(json['fourthOfficial'], isNull);
    expect(json.containsKey('score'), isFalse);
    expect(json.containsKey('events'), isFalse);
    expect(json.containsKey('status'), isFalse);
    expect(json.containsKey('sync'), isFalse);

    final restored = MatchConfigurationPayload.fromJson(json);
    expect(restored.homeTeamId, 'home');
    expect(restored.halfDurationSeconds, 2700);
    expect(restored.extraTimeEnabled, isTrue);
    expect(restored.updatedAt, DateTime.utc(2026, 11, 21, 11, 5));
  });

  test('an unknown payload version is rejected', () {
    expect(
      () => MatchConfigurationPayload.fromJson({
        'payloadVersion': 2,
        'matchId': 'match-1',
      }),
      throwsFormatException,
    );
  });
}
