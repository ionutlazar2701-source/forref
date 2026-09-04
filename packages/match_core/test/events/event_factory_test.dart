import 'package:match_core/match_core.dart';
import 'package:test/test.dart';

void main() {
  const factory = EventFactory();
  const validator = EventValidator();
  final now = DateTime.utc(2026, 9, 3, 18);

  MatchEvent goal({required EventData data}) => factory.create(
        eventId: 'e',
        matchId: 'm',
        type: EventType.goal,
        periodId: PeriodId.firstHalf,
        matchTime: 100,
        now: now,
        data: data,
      );

  test('identified player is complete', () {
    final event = goal(
      data: const EventData(
        teamId: 'h',
        player: PlayerRef(
          playerId: 'p1',
          shirtNumber: 9,
          isUnknown: false,
        ),
      ),
    );
    expect(event.status, EventStatus.complete);
    expect(validator.isIncomplete(event), isFalse);
  });

  test('unknown player without number is incomplete', () {
    final event = goal(
      data: const EventData(
        teamId: 'h',
        player: PlayerRef(isUnknown: true),
      ),
    );
    expect(event.status, EventStatus.incomplete);
  });

  test('free shirt number is complete', () {
    final event = goal(
      data: const EventData(
        teamId: 'h',
        player: PlayerRef(shirtNumber: 37, isUnknown: true),
      ),
    );
    expect(event.status, EventStatus.complete);
  });

  test('sub with shirt on IN is complete', () {
    final event = factory.create(
      eventId: 's',
      matchId: 'm',
      type: EventType.substitution,
      periodId: PeriodId.firstHalf,
      matchTime: 200,
      now: now,
      data: const EventData(
        teamId: 'h',
        out: PlayerRef(playerId: 'p1', isUnknown: false),
        inPlayer: PlayerRef(shirtNumber: 18, isUnknown: true),
      ),
    );
    expect(event.status, EventStatus.complete);
  });
}
