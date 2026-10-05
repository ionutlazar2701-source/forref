import '../authority.dart';
import '../capture/capture_context.dart';
import '../match_record.dart';
import '../projection/deterministic_match_projector.dart';
import '../projection/projection_context.dart';
import '../projection/projection_trust.dart';
import '../projection/temporal_match_projection.dart';
import '../record_kind.dart';
import '../semantics/match_record_semantic_type.dart';
import '../semantics/production_semantics_resolver.dart';
import '../semantics/v1_semantic_payload.dart';

/// Active period a goal may bind to. Disposable. Not a stored match state.
final class AdmittedGoalPeriod {
  const AdmittedGoalPeriod({
    required this.periodStart,
    required this.period,
  });

  final MatchRecord periodStart;
  final PeriodIdentity period;
}

/// Fail-closed admission for one goal. Does not commit a record.
sealed class GoalAdmission {
  const GoalAdmission();
}

final class GoalAdmitted extends GoalAdmission {
  const GoalAdmitted(this.period);

  final AdmittedGoalPeriod period;
}

final class GoalRejected extends GoalAdmission {
  const GoalRejected(this.reason);

  final String reason;
}

/// Whether [context] may commit a goal against the current Match Memory.
///
/// UI state, legacy elapsed time, and wall-clock chronology are not inputs.
GoalAdmission assessGoalAdmission({
  required List<MatchRecord> records,
  required CaptureContext context,
}) {
  if (context.authorityScope is! MainRefereeScope) {
    return const GoalRejected('GOAL requires MAIN_REFEREE capture authority');
  }
  if (context.authorityPrincipalId.isEmpty) {
    return const GoalRejected('GOAL requires an authority principal');
  }
  if (context.schemaVersion != 1) {
    return const GoalRejected('GOAL requires schema version 1');
  }
  if (context.authorityGeneration < 1) {
    return const GoalRejected('GOAL requires a valid authority generation');
  }

  final generations = <int>{};
  for (final record in records) {
    final authority = record.authorityContext;
    if (authority?.scope is! MainRefereeScope) continue;
    final generation = authority?.generation?.value;
    if (generation != null) generations.add(generation);
  }
  if (generations.length > 1) {
    return const GoalRejected('GOAL capture authority is ambiguous');
  }
  if (generations.isNotEmpty &&
      !generations.contains(context.authorityGeneration)) {
    return const GoalRejected(
      'GOAL capture authority generation does not match',
    );
  }

  if (_abandoned(records)) {
    return const GoalRejected('GOAL requires a match that has not been abandoned');
  }

  final lineage = periodLineage(records: records);
  if (lineage.ambiguous || lineage.endAmbiguous) {
    return const GoalRejected('GOAL has ambiguous temporal lineage');
  }

  final projection = DeterministicMatchProjector(ProductionSemanticsResolver())
      .projectRecords(
    matchId: context.matchId,
    records: records,
    context: ProjectionContext(
      evaluatedAuthorityGeneration: context.projectionAuthorityGeneration,
    ),
  );
  final temporal = TemporalMatchProjection.derive(
    projection: projection,
    records: records,
  );
  if (temporal.matchNormallyEnded) {
    return const GoalRejected(
      'GOAL requires a match that has not normally ended',
    );
  }
  if (projection.trustFor(ProjectionFacet.temporal) != ProjectionTrust.trusted &&
      records.isNotEmpty) {
    return const GoalRejected('GOAL requires trusted temporal lineage');
  }

  final active = lineage.activeStart;
  final payload = active?.payload;
  if (active == null ||
      payload is! TemporalTransitionPayload ||
      payload.period == null) {
    return const GoalRejected('GOAL requires one active period');
  }
  final history = findSuspensionHistory(
    records: records,
    activePeriod: payload.period,
  );
  if (history.formallySuspended) {
    return const GoalRejected('GOAL requires an active playing period');
  }

  return GoalAdmitted(
    AdmittedGoalPeriod(periodStart: active, period: payload.period!),
  );
}

bool _abandoned(List<MatchRecord> records) {
  for (final record in records) {
    final payload = record.payload;
    if (record.recordKind == RecordKind.temporalFact &&
        payload is TemporalTransitionPayload &&
        payload.semanticType == V1SemanticTypeCode.matchAbandoned) {
      return true;
    }
  }
  return false;
}
