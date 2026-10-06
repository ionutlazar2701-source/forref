import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/app_scope.dart';
import 'package:referee_phone/infrastructure/temporal/phone_temporal_evidence_store.dart';

/// Goal score and history derived from Match Memory for phone read surfaces.
final class GoalMatchReadModel {
  const GoalMatchReadModel({
    required this.projection,
    required this.legacyGoalEventCount,
  });

  final GoalMatchProjection projection;
  final int legacyGoalEventCount;

  int get homeScore => projection.homeScore;
  int get awayScore => projection.awayScore;

  /// Legacy Drift goal rows exist but Match Memory has no GOAL records.
  bool get legacyGoalsOnly =>
      legacyGoalEventCount > 0 && projection.goals.isEmpty;
}

/// One row in a mixed summary history list.
final class SummaryHistoryEntry {
  const SummaryHistoryEntry.goal(this.goal) : legacyEvent = null;
  const SummaryHistoryEntry.legacy(this.legacyEvent) : goal = null;

  final ProjectedGoal? goal;
  final MatchEvent? legacyEvent;

  int get _sortMicros {
    final projected = goal;
    if (projected != null) {
      final temporal = projected.temporal;
      final duration = temporal.exactPlayingTime ??
          temporal.playingTimeLowerBound ??
          Duration.zero;
      return duration.inMicroseconds;
    }
    return legacyEvent!.matchTime * 1000000;
  }
}

/// Loads [GoalMatchProjection] when the match boundary is present.
Future<GoalMatchReadModel?> loadGoalMatchReadModel(
  AppScope scope,
  String matchId, {
  required Match legacyMatch,
}) async {
  final boundary = scope.matchApplication;
  final identity = scope.captureIdentity;
  if (boundary == null || identity == null) return null;

  final records = await boundary.durableStore.readCommittedForMatch(matchId);
  final evidence = await resolveRecordedEvidence(
    scope.temporalEvidence,
    records,
  );
  final projection = GoalMatchProjection.derive(
    records: records,
    evidence: evidence,
  );
  final legacyGoals = legacyMatch.events
      .where((event) => event.type == EventType.goal)
      .length;
  return GoalMatchReadModel(
    projection: projection,
    legacyGoalEventCount: legacyGoals,
  );
}

Future<List<TemporalEvidence>> resolveRecordedEvidence(
  PhoneTemporalEvidenceStore? evidence,
  List<MatchRecord> records,
) async {
  if (evidence == null) return const [];
  final ids = <String>{};
  for (final record in records) {
    ids.addAll(record.temporalContext?.evidenceIds ?? const <String>[]);
  }
  final resolved = <TemporalEvidence>[];
  for (final id in ids) {
    final item = await evidence.resolve(id);
    if (item != null) resolved.add(item);
  }
  return resolved;
}

/// Goals from Match Memory plus non-goal legacy events. Goal appears once.
List<SummaryHistoryEntry> buildSummaryHistory({
  required GoalMatchProjection projection,
  required List<MatchEvent> legacyEvents,
}) {
  final entries = <SummaryHistoryEntry>[
    for (final goal in projection.goals) SummaryHistoryEntry.goal(goal),
    for (final event in legacyEvents)
      if (event.type != EventType.goal) SummaryHistoryEntry.legacy(event),
  ];
  entries.sort((a, b) => b._sortMicros.compareTo(a._sortMicros));
  return entries;
}
