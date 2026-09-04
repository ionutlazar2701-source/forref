import 'package:match_core/match_core.dart';
import 'package:test/test.dart';

void main() {
  test('frozen event types exist', () {
    expect(EventType.goal.jsonValue, 'goal');
    expect(EventType.yellowCard.jsonValue, 'yellow_card');
    expect(EventType.redCard.jsonValue, 'red_card');
    expect(EventType.substitution.jsonValue, 'substitution');
    expect(EventType.injury.jsonValue, 'injury');
  });

  test('pens period is reserved', () {
    expect(PeriodId.penalties.jsonValue, 'pens');
  });

  test('match_core has no Flutter types in public API', () {
    const clock = MatchClock();
    expect(clock, isA<MatchClock>());
  });
}
