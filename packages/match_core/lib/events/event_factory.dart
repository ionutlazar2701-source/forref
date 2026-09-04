import '../enums/enums.dart';
import '../models/event.dart';
import 'event_validator.dart';

/// Builds a [MatchEvent] from capture input. Sets [MatchEvent.status] via [EventValidator].
final class EventFactory {
  const EventFactory({this.validator = const EventValidator()});

  final EventValidator validator;

  MatchEvent create({
    required String eventId,
    required String matchId,
    required EventType type,
    required PeriodId periodId,
    required int matchTime,
    required DateTime now,
    required EventData data,
  }) {
    final utc = now.toUtc();
    final incomplete = validator.isDataIncomplete(type, data);
    return MatchEvent(
      eventId: eventId,
      matchId: matchId,
      type: type,
      status: incomplete ? EventStatus.incomplete : EventStatus.complete,
      periodId: periodId,
      matchTime: matchTime,
      createdAt: utc,
      updatedAt: utc,
      data: data,
    );
  }
}
