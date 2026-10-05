import '../match_record.dart';
import '../projection/active_period_elapsed.dart';
import '../projection/deterministic_match_projector.dart';
import '../projection/projection_context.dart';
import '../projection/temporal_match_projection.dart';
import '../record_kind.dart';
import '../relationships.dart';
import '../semantics/production_semantics_resolver.dart';
import '../semantics/v1_semantic_payload.dart';
import '../temporal.dart';

/// Reconstructed match time for one goal. Not a display string.
///
/// [exactElapsed] is set only for [TemporalContinuityStatus.exactContinuity].
/// Missing or cross-domain evidence stays [temporallyUncertain] and does not
/// become a zero elapsed time.
final class GoalTemporalReading {
  const GoalTemporalReading({
    required this.continuity,
    required this.exactElapsed,
    required this.elapsedLowerBound,
    required this.elapsedUpperBound,
  });

  static const uncertain = GoalTemporalReading(
    continuity: TemporalContinuityStatus.continuityUnresolved,
    exactElapsed: null,
    elapsedLowerBound: null,
    elapsedUpperBound: null,
  );

  final TemporalContinuityStatus continuity;
  final Duration? exactElapsed;
  final Duration? elapsedLowerBound;
  final Duration? elapsedUpperBound;

  bool get temporallyUncertain =>
      continuity != TemporalContinuityStatus.exactContinuity;

  @override
  bool operator ==(Object other) {
    return other is GoalTemporalReading &&
        continuity == other.continuity &&
        exactElapsed == other.exactElapsed &&
        elapsedLowerBound == other.elapsedLowerBound &&
        elapsedUpperBound == other.elapsedUpperBound;
  }

  @override
  int get hashCode => Object.hash(
        continuity,
        exactElapsed,
        elapsedLowerBound,
        elapsedUpperBound,
      );
}

/// One goal rebuilt from Match Memory. Order is origin order, not recordedAt.
final class ProjectedGoal {
  const ProjectedGoal({
    required this.recordId,
    required this.scoringSide,
    required this.period,
    required this.temporal,
    required this.originSequence,
    this.playerId,
    this.playerNumber,
  });

  final String recordId;
  final GoalScoringSide scoringSide;
  final PeriodIdentity period;
  final String? playerId;
  final String? playerNumber;
  final GoalTemporalReading temporal;
  final int originSequence;

  @override
  bool operator ==(Object other) {
    return other is ProjectedGoal &&
        recordId == other.recordId &&
        scoringSide == other.scoringSide &&
        period == other.period &&
        playerId == other.playerId &&
        playerNumber == other.playerNumber &&
        temporal == other.temporal &&
        originSequence == other.originSequence;
  }

  @override
  int get hashCode => Object.hash(
        recordId,
        scoringSide,
        period,
        playerId,
        playerNumber,
        temporal,
        originSequence,
      );
}

/// Disposable goal history and score. Neither field is Match Memory.
final class GoalMatchProjection {
  const GoalMatchProjection({
    required this.history,
    required this.homeScore,
    required this.awayScore,
  });

  static const empty = GoalMatchProjection(
    history: [],
    homeScore: 0,
    awayScore: 0,
  );

  final List<ProjectedGoal> history;
  final int homeScore;
  final int awayScore;

  @override
  bool operator ==(Object other) {
    return other is GoalMatchProjection &&
        homeScore == other.homeScore &&
        awayScore == other.awayScore &&
        _sameHistory(history, other.history);
  }

  @override
  int get hashCode => Object.hash(homeScore, awayScore, Object.hashAll(history));
}

/// Rebuilds goal history and score from committed goal records.
///
/// [recordedEvidence] resolves temporal evidence ids. It is not authority.
/// A later [MatchRecord.recordedAt] does not reorder history or replace score.
GoalMatchProjection deriveGoalMatchProjection({
  required List<MatchRecord> records,
  required List<TemporalEvidence> recordedEvidence,
  int evaluatedAuthorityGeneration = 1,
}) {
  final goals = [
    for (final record in records)
      if (_isGoal(record)) record,
  ]..sort(deterministicRecordOrder);

  final history = <ProjectedGoal>[];
  var home = 0;
  var away = 0;
  for (final goal in goals) {
    final payload = goal.payload as GoalPayload;
    if (!_boundToPeriodStart(goal, records)) {
      history.add(
        ProjectedGoal(
          recordId: goal.recordId,
          scoringSide: payload.scoringSide,
          period: payload.period,
          playerId: payload.playerId,
          playerNumber: payload.playerNumber,
          temporal: GoalTemporalReading.uncertain,
          originSequence: goal.originSequence,
        ),
      );
      continue;
    }
    switch (payload.scoringSide) {
      case GoalScoringSide.home:
        home++;
      case GoalScoringSide.away:
        away++;
    }
    history.add(
      ProjectedGoal(
        recordId: goal.recordId,
        scoringSide: payload.scoringSide,
        period: payload.period,
        playerId: payload.playerId,
        playerNumber: payload.playerNumber,
        temporal: _reading(
          records: records,
          goal: goal,
          evidence: recordedEvidence,
          evaluatedAuthorityGeneration: evaluatedAuthorityGeneration,
        ),
        originSequence: goal.originSequence,
      ),
    );
  }

  return GoalMatchProjection(
    history: List.unmodifiable(history),
    homeScore: home,
    awayScore: away,
  );
}

bool _isGoal(MatchRecord record) {
  return record.recordKind == RecordKind.action && record.payload is GoalPayload;
}

bool _boundToPeriodStart(MatchRecord goal, List<MatchRecord> records) {
  final payload = goal.payload;
  if (payload is! GoalPayload) return false;
  final periodStart = anchoredPeriodStart(records, payload.period);
  if (periodStart == null) return false;
  return goal.relationships.any(
    (link) =>
        link is CausalDependency && link.targetRecordId == periodStart.recordId,
  );
}

GoalTemporalReading _reading({
  required List<MatchRecord> records,
  required MatchRecord goal,
  required List<TemporalEvidence> evidence,
  required int evaluatedAuthorityGeneration,
}) {
  final payload = goal.payload;
  if (payload is! GoalPayload) return GoalTemporalReading.uncertain;
  final sample = _sample(goal, evidence);
  if (sample == null) return GoalTemporalReading.uncertain;

  final prior = [
    for (final record in records)
      if (deterministicRecordOrder(record, goal) < 0) record,
  ];
  final projection = DeterministicMatchProjector(ProductionSemanticsResolver())
      .projectRecords(
    matchId: goal.matchId,
    records: prior,
    context: ProjectionContext(
      evaluatedAuthorityGeneration: evaluatedAuthorityGeneration,
    ),
  );
  final temporal = TemporalMatchProjection.derive(
    projection: projection,
    records: prior,
  );
  if (temporal.activePeriod != payload.period) {
    return GoalTemporalReading.uncertain;
  }
  final elapsed = deriveActivePeriodElapsed(
    temporal: temporal,
    projection: projection,
    records: prior,
    anchor: null,
    current: sample,
    recordedEvidence: evidence,
  );
  return switch (elapsed.continuity) {
    TemporalContinuityStatus.exactContinuity
        when elapsed.exactElapsed != null =>
      GoalTemporalReading(
        continuity: TemporalContinuityStatus.exactContinuity,
        exactElapsed: elapsed.exactElapsed,
        elapsedLowerBound: null,
        elapsedUpperBound: null,
      ),
    TemporalContinuityStatus.boundedContinuity
        when elapsed.elapsedLowerBound != null &&
            elapsed.elapsedUpperBound != null =>
      GoalTemporalReading(
        continuity: TemporalContinuityStatus.boundedContinuity,
        exactElapsed: null,
        elapsedLowerBound: elapsed.elapsedLowerBound,
        elapsedUpperBound: elapsed.elapsedUpperBound,
      ),
    _ => GoalTemporalReading.uncertain,
  };
}

TemporalEvidence? _sample(MatchRecord goal, List<TemporalEvidence> evidence) {
  final ids = goal.temporalContext?.evidenceIds ?? const <String>[];
  if (ids.isEmpty) return null;
  for (final id in ids) {
    for (final item in evidence) {
      if (item.evidenceId == id) return item;
    }
  }
  return null;
}

bool _sameHistory(List<ProjectedGoal> left, List<ProjectedGoal> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
