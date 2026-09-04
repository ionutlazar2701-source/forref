import '../enums/enums.dart';
import '../history/history_builder.dart';
import '../models/event.dart';
import '../models/match.dart';
import '../scoring/score_calculator.dart';
import 'event_validator.dart';

/// Applies an event or edit to a [Match]. Score is derived, not patched.
final class EventReducer {
  const EventReducer({
    this.scores = const ScoreCalculator(),
    this.validator = const EventValidator(),
    this.history = const HistoryBuilder(),
  });

  final ScoreCalculator scores;
  final EventValidator validator;
  final HistoryBuilder history;

  Match applyNewEvent(Match match, MatchEvent event) {
    if (match.events.any((e) => e.eventId == event.eventId)) {
      throw StateError('Duplicate eventId ${event.eventId}');
    }
    final events = [...match.events, event];
    return match.copyWith(
      events: events,
      score: _score(match, events),
      updatedAt: event.updatedAt,
    );
  }

  Match applyEventUpdate(
    Match match,
    MatchEvent updated, {
    required String historyId,
    required DateTime now,
  }) {
    final index = match.events.indexWhere((e) => e.eventId == updated.eventId);
    if (index < 0) {
      throw StateError('Unknown eventId ${updated.eventId}');
    }
    final previous = match.events[index];
    final utc = now.toUtc();
    final incomplete = validator.isIncomplete(updated);
    final next = updated.copyWith(
      status: incomplete ? EventStatus.incomplete : EventStatus.complete,
      updatedAt: utc,
    );
    final events = [...match.events];
    events[index] = next;
    final entry = history.update(
      historyId: historyId,
      previous: previous,
      next: next,
      changedAt: utc,
    );
    return match.copyWith(
      events: events,
      history: [...match.history, entry],
      score: _score(match, events),
      updatedAt: utc,
    );
  }

  /// Undo last save. The 5 s window is UI; this removes the last event only.
  Match undoNewEvent(
    Match match, {
    required String eventId,
    required String historyId,
    required DateTime now,
  }) {
    if (match.events.isEmpty || match.events.last.eventId != eventId) {
      throw StateError('Undo applies to the last saved event only');
    }
    final removed = match.events.last;
    final utc = now.toUtc();
    final events = match.events.sublist(0, match.events.length - 1);
    return match.copyWith(
      events: events,
      history: [
        ...match.history,
        history.undoCreate(
          historyId: historyId,
          removed: removed,
          changedAt: utc,
        ),
      ],
      score: _score(match, events),
      updatedAt: utc,
    );
  }

  Score _score(Match match, List<MatchEvent> events) {
    return scores.fromEvents(
      events,
      homeTeamId: match.teams.home.teamId,
      awayTeamId: match.teams.away.teamId,
    );
  }
}
