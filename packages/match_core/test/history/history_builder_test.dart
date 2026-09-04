import 'package:match_core/match_core.dart';
import 'package:test/test.dart';

void main() {
  test('history stores full event snapshots and keeps eventId', () {
    final now = DateTime.utc(2026, 9, 3);
    final previous = MatchEvent(
      eventId: 'e',
      matchId: 'm',
      type: EventType.goal,
      status: EventStatus.complete,
      periodId: PeriodId.firstHalf,
      matchTime: 0,
      createdAt: now,
      updatedAt: now,
      data: const EventData(teamId: 'h', isOwnGoal: false),
    );
    final next = previous.copyWith(type: EventType.yellowCard);
    final entry = const HistoryBuilder().update(
      historyId: 'h1',
      previous: previous,
      next: next,
      changedAt: now,
    );
    expect(entry.eventId, 'e');
    expect(entry.action, HistoryAction.update);
    expect(entry.previousValue['type'], 'goal');
    expect(entry.newValue['type'], 'yellow_card');
  });

  test('history rejects eventId change', () {
    final now = DateTime.utc(2026, 9, 3);
    final previous = MatchEvent(
      eventId: 'e1',
      matchId: 'm',
      type: EventType.goal,
      status: EventStatus.complete,
      periodId: PeriodId.firstHalf,
      matchTime: 0,
      createdAt: now,
      updatedAt: now,
      data: const EventData(),
    );
    final next = MatchEvent(
      eventId: 'e2',
      matchId: 'm',
      type: EventType.goal,
      status: EventStatus.complete,
      periodId: PeriodId.firstHalf,
      matchTime: 0,
      createdAt: now,
      updatedAt: now,
      data: const EventData(),
    );
    expect(
      () => const HistoryBuilder().update(
        historyId: 'h',
        previous: previous,
        next: next,
        changedAt: now,
      ),
      throwsArgumentError,
    );
  });
}
