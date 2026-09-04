import '../enums/enums.dart';
import '../models/event.dart';
import '../models/player.dart';

/// Completeness from capture data. [MatchEvent.status] is stored on the event.
final class EventValidator {
  const EventValidator();

  bool isIncomplete(MatchEvent event) =>
      isDataIncomplete(event.type, event.data);

  int incompleteCount(Iterable<MatchEvent> events) =>
      events.where(isIncomplete).length;

  bool isDataIncomplete(EventType type, EventData data) {
    switch (type) {
      case EventType.goal:
      case EventType.yellowCard:
      case EventType.redCard:
      case EventType.injury:
        return !_identified(data.player);
      case EventType.substitution:
        return !_identified(data.out) || !_identified(data.inPlayer);
    }
  }

  bool _identified(PlayerRef? ref) {
    if (ref == null) return false;
    if (ref.playerId != null && ref.playerId!.isNotEmpty) return true;
    if (ref.shirtNumber != null) return true;
    return false;
  }
}
