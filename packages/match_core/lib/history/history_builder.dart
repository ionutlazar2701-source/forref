import '../enums/enums.dart';
import '../models/event.dart';
import '../models/history_entry.dart';
import '../serialization/match_json.dart';

/// Append-only snapshots. Never change [MatchEvent.eventId].
final class HistoryBuilder {
  const HistoryBuilder({this.codec = const MatchJson()});

  final MatchJson codec;

  HistoryEntry update({
    required String historyId,
    required MatchEvent previous,
    required MatchEvent next,
    required DateTime changedAt,
  }) {
    if (previous.eventId != next.eventId) {
      throw ArgumentError('eventId must stay stable');
    }
    return HistoryEntry(
      historyId: historyId,
      eventId: previous.eventId,
      action: HistoryAction.update,
      changedAt: changedAt.toUtc(),
      previousValue: codec.eventToJson(previous),
      newValue: codec.eventToJson(next),
    );
  }

  HistoryEntry undoCreate({
    required String historyId,
    required MatchEvent removed,
    required DateTime changedAt,
  }) {
    return HistoryEntry(
      historyId: historyId,
      eventId: removed.eventId,
      action: HistoryAction.undo,
      changedAt: changedAt.toUtc(),
      previousValue: codec.eventToJson(removed),
      newValue: const {},
    );
  }

  HistoryEntry matchFields({
    required String historyId,
    required HistoryAction action,
    required DateTime changedAt,
    required Map<String, Object?> previousValue,
    required Map<String, Object?> newValue,
  }) {
    return HistoryEntry(
      historyId: historyId,
      eventId: null,
      action: action,
      changedAt: changedAt.toUtc(),
      previousValue: previousValue,
      newValue: newValue,
    );
  }
}
