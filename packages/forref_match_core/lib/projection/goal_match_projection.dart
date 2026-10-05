import '../match_record.dart';
import '../record_kind.dart';
import '../relationships.dart';
import '../semantics/match_record_semantic_type.dart';
import '../semantics/v1_semantic_payload.dart';
import '../temporal.dart';
import 'active_period_elapsed.dart';
import 'temporal_match_projection.dart';

/// Formatting-free playing-time placement for one committed goal.
///
/// Exact continuity exposes [exactPlayingTime]. Bounded continuity exposes
/// bounds only. Unresolved continuity exposes neither. Nothing here is a
/// clock string, a legacy elapsed value, or [MatchRecord.recordedAt].
final class ProjectedGoalTemporal {
  const ProjectedGoalTemporal({
    required this.continuity,
    required this.exactPlayingTime,
    required this.playingTimeLowerBound,
    required this.playingTimeUpperBound,
    required this.period,
  });

  final TemporalContinuityStatus continuity;
  final Duration? exactPlayingTime;
  final Duration? playingTimeLowerBound;
  final Duration? playingTimeUpperBound;
  final PeriodIdentity? period;

  static const unresolved = ProjectedGoalTemporal(
    continuity: TemporalContinuityStatus.continuityUnresolved,
    exactPlayingTime: null,
    playingTimeLowerBound: null,
    playingTimeUpperBound: null,
    period: null,
  );

  @override
  bool operator ==(Object other) {
    return other is ProjectedGoalTemporal &&
        continuity == other.continuity &&
        exactPlayingTime == other.exactPlayingTime &&
        playingTimeLowerBound == other.playingTimeLowerBound &&
        playingTimeUpperBound == other.playingTimeUpperBound &&
        period == other.period;
  }

  @override
  int get hashCode => Object.hash(
        continuity,
        exactPlayingTime,
        playingTimeLowerBound,
        playingTimeUpperBound,
        period,
      );
}

/// One committed GOAL in disposable history.
///
/// [legallySuperseded] goals stay in history and do not count toward the score.
final class ProjectedGoal {
  const ProjectedGoal({
    required this.recordId,
    required this.creditedSide,
    required this.temporal,
    required this.legallySuperseded,
  });

  final String recordId;
  final CreditedSide creditedSide;
  final ProjectedGoalTemporal temporal;
  final bool legallySuperseded;

  bool get countsTowardScore => !legallySuperseded;

  @override
  bool operator ==(Object other) {
    return other is ProjectedGoal &&
        recordId == other.recordId &&
        creditedSide == other.creditedSide &&
        temporal == other.temporal &&
        legallySuperseded == other.legallySuperseded;
  }

  @override
  int get hashCode => Object.hash(
        recordId,
        creditedSide,
        temporal,
        legallySuperseded,
      );
}

/// Disposable score and goal history rebuilt from committed GOAL records.
///
/// Not a persisted score. A legally superseded GOAL remains in [goals] and
/// does not increment [homeScore] or [awayScore].
final class GoalMatchProjection {
  const GoalMatchProjection({
    required this.homeScore,
    required this.awayScore,
    required this.goals,
  });

  static const empty = GoalMatchProjection(
    homeScore: 0,
    awayScore: 0,
    goals: [],
  );

  final int homeScore;
  final int awayScore;
  final List<ProjectedGoal> goals;

  static GoalMatchProjection derive({
    required List<MatchRecord> records,
    List<TemporalEvidence> evidence = const [],
  }) {
    final sorted = [...records]..sort(deterministicRecordOrder);
    final evidenceById = {
      for (final item in evidence) item.evidenceId: item,
    };
    final superseded = <String>{};
    for (final record in sorted) {
      if (record.recordKind != RecordKind.legalSupersession) continue;
      for (final link in record.relationships) {
        if (link is LegalSupersessionTarget) {
          superseded.add(link.targetRecordId);
        }
      }
    }

    var home = 0;
    var away = 0;
    final goals = <ProjectedGoal>[];
    for (final record in sorted) {
      final payload = record.payload;
      if (record.recordKind != RecordKind.humanDetermination ||
          payload is! GoalPayload) {
        continue;
      }
      final legallySuperseded = superseded.contains(record.recordId);
      if (!legallySuperseded) {
        switch (payload.creditedSide) {
          case CreditedSide.home:
            home++;
          case CreditedSide.away:
            away++;
        }
      }
      goals.add(
        ProjectedGoal(
          recordId: record.recordId,
          creditedSide: payload.creditedSide,
          temporal: _temporalAtGoal(
            goal: record,
            records: sorted,
            evidenceById: evidenceById,
          ),
          legallySuperseded: legallySuperseded,
        ),
      );
    }

    return GoalMatchProjection(
      homeScore: home,
      awayScore: away,
      goals: List.unmodifiable(goals),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GoalMatchProjection &&
        homeScore == other.homeScore &&
        awayScore == other.awayScore &&
        _goalsEqual(goals, other.goals);
  }

  @override
  int get hashCode => Object.hash(homeScore, awayScore, Object.hashAll(goals));
}

bool _goalsEqual(List<ProjectedGoal> left, List<ProjectedGoal> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

ProjectedGoalTemporal _temporalAtGoal({
  required MatchRecord goal,
  required List<MatchRecord> records,
  required Map<String, TemporalEvidence> evidenceById,
}) {
  final periodStart = _periodStartFor(goal, records);
  final period = periodStart?.payload is TemporalTransitionPayload
      ? (periodStart!.payload as TemporalTransitionPayload).period
      : null;
  final goalEvidence = _firstEvidence(goal, evidenceById);
  final anchor = _firstEvidence(periodStart, evidenceById);
  if (periodStart == null ||
      period == null ||
      goalEvidence == null ||
      anchor == null) {
    return _unresolved(period);
  }

  final anchored = anchoredPeriodStart(records, period);
  if (anchored == null || anchored.recordId != periodStart.recordId) {
    return _unresolved(period);
  }
  final history = findSuspensionHistory(
    records: records,
    activePeriod: period,
  );
  if (history.overlapping ||
      history.cycles.any((cycle) => cycle.endAmbiguous)) {
    return _unresolved(period);
  }

  final segments = <_PlayingSpan>[];
  var cursor = anchor;
  for (final cycle in history.cycles) {
    final suspensionStart = _firstEvidence(cycle.start, evidenceById);
    if (suspensionStart == null) return _unresolved(period);
    final againstStart = _order(goalEvidence, suspensionStart);
    if (againstStart == _SampleOrder.before) {
      segments.add(_span(cursor, goalEvidence));
      return _fromSegments(period, segments);
    }
    if (againstStart != _SampleOrder.after) return _unresolved(period);
    segments.add(_span(cursor, suspensionStart));
    final suspensionEnd = cycle.end;
    if (cycle.open || suspensionEnd == null) return _unresolved(period);
    final resumption = _firstEvidence(suspensionEnd, evidenceById);
    if (resumption == null) return _unresolved(period);
    final againstEnd = _order(goalEvidence, resumption);
    if (againstEnd != _SampleOrder.after) return _unresolved(period);
    cursor = resumption;
  }
  segments.add(_span(cursor, goalEvidence));
  return _fromSegments(period, segments);
}

MatchRecord? _periodStartFor(MatchRecord goal, List<MatchRecord> records) {
  final byId = {for (final record in records) record.recordId: record};
  for (final link in goal.relationships) {
    if (link is! CausalDependency) continue;
    final target = byId[link.targetRecordId];
    if (target == null) continue;
    final payload = target.payload;
    if (target.recordKind == RecordKind.temporalFact &&
        payload is TemporalTransitionPayload &&
        payload.semanticType == V1SemanticTypeCode.periodStarted &&
        payload.period != null) {
      return target;
    }
  }
  return null;
}

TemporalEvidence? _firstEvidence(
  MatchRecord? record,
  Map<String, TemporalEvidence> evidenceById,
) {
  final ids = record?.temporalContext?.evidenceIds ?? const <String>[];
  if (ids.isEmpty) return null;
  return evidenceById[ids.first];
}

ProjectedGoalTemporal _unresolved(PeriodIdentity? period) {
  return ProjectedGoalTemporal(
    continuity: TemporalContinuityStatus.continuityUnresolved,
    exactPlayingTime: null,
    playingTimeLowerBound: null,
    playingTimeUpperBound: null,
    period: period,
  );
}

ProjectedGoalTemporal _fromSegments(
  PeriodIdentity period,
  List<_PlayingSpan> segments,
) {
  if (segments.isEmpty) {
    return const ProjectedGoalTemporal(
      continuity: TemporalContinuityStatus.exactContinuity,
      exactPlayingTime: Duration.zero,
      playingTimeLowerBound: null,
      playingTimeUpperBound: null,
      period: null,
    );
  }
  var sum = segments.first;
  for (final segment in segments.skip(1)) {
    sum = _addSpans(sum, segment);
  }
  if (sum.unresolved) return _unresolved(period);
  if (sum.exact != null) {
    return ProjectedGoalTemporal(
      continuity: TemporalContinuityStatus.exactContinuity,
      exactPlayingTime: sum.exact,
      playingTimeLowerBound: null,
      playingTimeUpperBound: null,
      period: period,
    );
  }
  return ProjectedGoalTemporal(
    continuity: TemporalContinuityStatus.boundedContinuity,
    exactPlayingTime: null,
    playingTimeLowerBound: sum.lower,
    playingTimeUpperBound: sum.upper,
    period: period,
  );
}

enum _SampleOrder { before, after, unordered }

_SampleOrder _order(TemporalEvidence event, TemporalEvidence boundary) {
  if (event.continuityDomainId == null ||
      event.continuityDomainId != boundary.continuityDomainId ||
      event.monotonicElapsed == null ||
      boundary.monotonicElapsed == null) {
    return _SampleOrder.unordered;
  }
  final eventLower = event.monotonicElapsed!;
  final eventUpper = event.monotonicUpperBound ?? eventLower;
  final boundaryLower = boundary.monotonicElapsed!;
  final boundaryUpper = boundary.monotonicUpperBound ?? boundaryLower;
  if (eventUpper < eventLower || boundaryUpper < boundaryLower) {
    return _SampleOrder.unordered;
  }
  if (eventUpper <= boundaryLower) return _SampleOrder.before;
  if (boundaryUpper <= eventLower) return _SampleOrder.after;
  return _SampleOrder.unordered;
}

final class _PlayingSpan {
  const _PlayingSpan.unresolved()
      : exact = null,
        lower = null,
        upper = null,
        unresolved = true;

  const _PlayingSpan.exact(this.exact)
      : lower = null,
        upper = null,
        unresolved = false;

  const _PlayingSpan.bounded(this.lower, this.upper)
      : exact = null,
        unresolved = false;

  final Duration? exact;
  final Duration? lower;
  final Duration? upper;
  final bool unresolved;
}

_PlayingSpan _span(TemporalEvidence start, TemporalEvidence end) {
  if (start.continuityDomainId == null ||
      start.continuityDomainId != end.continuityDomainId ||
      start.monotonicElapsed == null ||
      end.monotonicElapsed == null) {
    return const _PlayingSpan.unresolved();
  }
  final startLower = start.monotonicElapsed!;
  final startUpper = start.monotonicUpperBound ?? startLower;
  final endLower = end.monotonicElapsed!;
  final endUpper = end.monotonicUpperBound ?? endLower;
  if (startUpper < startLower || endUpper < endLower || endLower < startUpper) {
    return const _PlayingSpan.unresolved();
  }
  final lower = endLower - startUpper;
  final upper = endUpper - startLower;
  if (start.isInterval || end.isInterval) {
    return _PlayingSpan.bounded(lower, upper);
  }
  return _PlayingSpan.exact(lower);
}

_PlayingSpan _addSpans(_PlayingSpan base, _PlayingSpan since) {
  if (base.unresolved || since.unresolved) {
    return const _PlayingSpan.unresolved();
  }
  if (base.exact != null && since.exact != null) {
    return _PlayingSpan.exact(base.exact! + since.exact!);
  }
  final baseLower = base.exact ?? base.lower!;
  final baseUpper = base.exact ?? base.upper!;
  final sinceLower = since.exact ?? since.lower!;
  final sinceUpper = since.exact ?? since.upper!;
  return _PlayingSpan.bounded(baseLower + sinceLower, baseUpper + sinceUpper);
}
