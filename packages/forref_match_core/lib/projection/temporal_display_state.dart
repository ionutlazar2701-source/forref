import '../semantics/v1_semantic_payload.dart';
import '../temporal.dart';
import 'active_period_elapsed.dart';
import 'match_projection_state.dart';
import 'projection_trust.dart';
import 'temporal_match_projection.dart';

/// Watch-facing temporal projection.
///
/// Disposable read model. It is not Match Memory, not a timer authority, and
/// not a sporting record. Presentation must switch on the variant before it
/// can read a football-time value. There is no shared elapsed accessor.
sealed class TemporalDisplayState {
  const TemporalDisplayState();
}

/// Exact running period. A ticking watch clock may use [footballTime].
///
/// [footballTime] is the format nominal base plus trusted active elapsed.
/// [period] is the authoritative phase. Continuity is exact.
final class RunningTrusted extends TemporalDisplayState {
  const RunningTrusted({
    required this.period,
    required this.nominalBase,
    required this.activeElapsed,
    required this.footballTime,
    required this.addedTime,
  }) : continuity = TemporalContinuityStatus.exactContinuity;

  final PeriodIdentity period;
  final Duration nominalBase;
  final Duration activeElapsed;
  final Duration footballTime;
  final TemporalContinuityStatus continuity;
  final AddedTimeDisplayContext addedTime;
}

/// Trusted lifecycle with no active-period ticking clock.
final class InactiveTrusted extends TemporalDisplayState {
  const InactiveTrusted({
    required this.lifecycle,
    this.endedPeriod,
    this.matchNormallyEnded = false,
    this.matchAbandoned = false,
    this.bothOrdinaryPeriodsEnded = false,
  });

  final InactiveLifecycle lifecycle;
  final PeriodIdentity? endedPeriod;
  final bool matchNormallyEnded;
  final bool matchAbandoned;
  final bool bothOrdinaryPeriodsEnded;
}

/// Why a trusted match is not in a running period.
enum InactiveLifecycle {
  /// Match started. No period has started.
  prePeriod,

  /// Period 1 has ended and period 2 has not started.
  interval,

  /// A period has ended and the next period has not started.
  awaitingNextPeriod,

  /// Match ended or abandoned.
  terminal,
}

/// Confirmed formal suspension. Active football-time does not tick.
///
/// [elapsed] must be matched before any frozen number is read.
/// [temporalTrust] is the suspension trust classification.
/// [suspensionEvidenceId] is a reference to temporal evidence, not a clock.
final class SuspendedTrusted extends TemporalDisplayState {
  const SuspendedTrusted({
    required this.period,
    required this.nominalBase,
    required this.elapsed,
    required this.addedTime,
    this.suspensionEvidenceId,
  }) : temporalTrust = ProjectionTrust.trusted;

  final PeriodIdentity period;
  final Duration nominalBase;
  final SuspensionElapsed elapsed;
  final ProjectionTrust temporalTrust;
  final String? suspensionEvidenceId;
  final AddedTimeDisplayContext addedTime;
}

/// Frozen active elapsed at suspension. Not a live clock.
sealed class SuspensionElapsed {
  const SuspensionElapsed();
}

final class ExactSuspensionElapsed extends SuspensionElapsed {
  const ExactSuspensionElapsed({
    required this.activeElapsed,
    required this.footballTime,
  });

  final Duration activeElapsed;
  final Duration footballTime;
}

/// Bounds only. No single exact match-time value.
final class BoundedSuspensionElapsed extends SuspensionElapsed {
  const BoundedSuspensionElapsed({
    required this.activeElapsedLowerBound,
    required this.activeElapsedUpperBound,
    required this.footballTimeLowerBound,
    required this.footballTimeUpperBound,
  });

  final Duration activeElapsedLowerBound;
  final Duration activeElapsedUpperBound;
  final Duration footballTimeLowerBound;
  final Duration footballTimeUpperBound;
}

final class UnavailableSuspensionElapsed extends SuspensionElapsed {
  const UnavailableSuspensionElapsed();
}

/// Provably bounded running time. Not an exact ticking clock.
///
/// Lower and upper bounds stay separate even when they are equal.
final class RunningBounded extends TemporalDisplayState {
  const RunningBounded({
    required this.period,
    required this.nominalBase,
    required this.activeElapsedLowerBound,
    required this.activeElapsedUpperBound,
    required this.footballTimeLowerBound,
    required this.footballTimeUpperBound,
    required this.addedTime,
  }) : continuity = TemporalContinuityStatus.boundedContinuity;

  /// Trusted phase, known independently of the exact instant.
  final PeriodIdentity period;
  final Duration nominalBase;
  final Duration activeElapsedLowerBound;
  final Duration activeElapsedUpperBound;
  final Duration footballTimeLowerBound;
  final Duration footballTimeUpperBound;
  final TemporalContinuityStatus continuity;
  final AddedTimeDisplayContext addedTime;
}

/// Current temporal or lifecycle truth is not enough for a live clock.
///
/// [lastProvenActiveElapsed] and [lastProvenPeriod] are historical context.
/// They are not the current match time and not the current phase.
final class Unresolved extends TemporalDisplayState {
  const Unresolved({
    required this.reason,
    this.lastProvenActiveElapsed,
    this.lastProvenPeriod,
  });

  final TemporalUnresolvedReason reason;
  final Duration? lastProvenActiveElapsed;
  final PeriodIdentity? lastProvenPeriod;
}

enum TemporalUnresolvedReason {
  missingAnchor,
  continuityUnresolved,
  lifecycleIncomplete,
  conflict,
  corruption,
  unsupportedSchema,
  staleAuthority,
  missingNominalBase,
}

/// Nominal football-time base and nominal length for one period.
///
/// Supplied by competition format. Previous-period overrun is not an input.
final class PeriodClockCoordinate {
  const PeriodClockCoordinate({
    required this.period,
    required this.nominalBase,
    required this.nominalLength,
  });

  final PeriodIdentity period;

  /// Football-time coordinate at which this period starts.
  final Duration nominalBase;

  /// Regulation length of this period. Distinct from [nominalBase].
  final Duration nominalLength;
}

/// Format clock context for phase-offset football-time.
///
/// Not Match Memory. A missing or duplicated period coordinate fails closed.
final class MatchFormatClockContext {
  MatchFormatClockContext({required List<PeriodClockCoordinate> periods})
      : periods = List<PeriodClockCoordinate>.unmodifiable(periods);

  final List<PeriodClockCoordinate> periods;

  PeriodClockCoordinate? coordinateFor(PeriodIdentity period) {
    PeriodClockCoordinate? found;
    for (final item in periods) {
      if (item.period != period) continue;
      if (found != null) return null;
      found = item;
    }
    if (found == null) return null;
    if (found.nominalBase.isNegative || found.nominalLength.isNegative) {
      return null;
    }
    return found;
  }
}

/// Display context for added-time fact classes that must not collapse.
///
/// Suggestion, referee decision, and public indication are not derived here.
/// This core has no authoritative public-indication semantic.
final class AddedTimeDisplayContext {
  const AddedTimeDisplayContext({
    required this.suggestion,
    required this.refereeDecision,
    required this.publicIndication,
    required this.elapsedBeyondNominal,
  });

  static const absent = AddedTimeDisplayContext(
    suggestion: null,
    refereeDecision: null,
    publicIndication: PublicIndicationUnsupported(),
    elapsedBeyondNominal: null,
  );

  final AddedTimeSuggestion? suggestion;
  final RefereeAddedTimeDecision? refereeDecision;
  final PublicIndicationUnsupported publicIndication;
  final ElapsedBeyondNominal? elapsedBeyondNominal;
}

/// FORREF suggestion. Not a referee decision and not a public indication.
final class AddedTimeSuggestion {
  const AddedTimeSuggestion(this.amount);

  final Duration amount;
}

/// Referee added-time decision. Not a suggestion and not a public indication.
final class RefereeAddedTimeDecision {
  const RefereeAddedTimeDecision(this.amount);

  final Duration amount;
}

/// No authoritative public-indication semantic exists to carry an amount.
final class PublicIndicationUnsupported {
  const PublicIndicationUnsupported();
}

/// Active elapsed past the format nominal length. Not a public indication.
final class ElapsedBeyondNominal {
  const ElapsedBeyondNominal(this.amount);

  final Duration amount;
}

/// Projects a watch display state from disposable temporal facts.
///
/// Does not read Match Memory, write a record, or consult the network.
/// The hot path passes the current monotonic sample through
/// [deriveActivePeriodElapsed], then calls this function.
///
/// [historicalLastProvenActiveElapsed] is prior context for [Unresolved]
/// only. It is never copied into a running clock.
TemporalDisplayState projectTemporalDisplay({
  required TemporalMatchProjection lifecycle,
  required ActivePeriodElapsedProjection elapsed,
  required MatchProjectionState projection,
  required MatchFormatClockContext format,
  TemporalEvidence? periodAnchor,
  TemporalEvidence? suspensionBoundary,
  Duration? historicalLastProvenActiveElapsed,
  PeriodIdentity? historicalLastProvenPeriod,
}) {
  final blocked = _blocked(
    lifecycle: lifecycle,
    projection: projection,
    historicalLastProvenActiveElapsed: historicalLastProvenActiveElapsed,
    historicalLastProvenPeriod: historicalLastProvenPeriod,
  );
  if (blocked != null) return blocked;

  if (_lineageUnreadable(lifecycle)) {
    return _unresolved(
      TemporalUnresolvedReason.conflict,
      historicalElapsed: historicalLastProvenActiveElapsed,
      historicalPeriod: historicalLastProvenPeriod,
    );
  }

  if (lifecycle.matchAbandoned || lifecycle.matchNormallyEnded) {
    return InactiveTrusted(
      lifecycle: InactiveLifecycle.terminal,
      endedPeriod: lifecycle.endedPeriod,
      matchNormallyEnded: lifecycle.matchNormallyEnded,
      matchAbandoned: lifecycle.matchAbandoned,
      bothOrdinaryPeriodsEnded: lifecycle.bothOrdinaryPeriodsEnded,
    );
  }

  final period = lifecycle.activePeriod;
  if (period != null && lifecycle.formallySuspended) {
    return _suspended(
      period: period,
      lifecycle: lifecycle,
      elapsed: elapsed,
      format: format,
      periodAnchor: periodAnchor,
      suspensionBoundary: suspensionBoundary,
      historicalLastProvenActiveElapsed: historicalLastProvenActiveElapsed,
      historicalLastProvenPeriod: historicalLastProvenPeriod,
    );
  }
  if (period != null) {
    return _running(
      period: period,
      elapsed: elapsed,
      format: format,
      periodAnchor: periodAnchor,
      historicalLastProvenActiveElapsed: historicalLastProvenActiveElapsed,
      historicalLastProvenPeriod: historicalLastProvenPeriod,
    );
  }
  if (lifecycle.intervalActive) {
    return InactiveTrusted(
      lifecycle: InactiveLifecycle.interval,
      endedPeriod: lifecycle.endedPeriod,
    );
  }
  if (lifecycle.temporallyIncomplete && lifecycle.endedPeriod == null) {
    return const InactiveTrusted(lifecycle: InactiveLifecycle.prePeriod);
  }
  if (lifecycle.endedPeriod != null) {
    return InactiveTrusted(
      lifecycle: InactiveLifecycle.awaitingNextPeriod,
      endedPeriod: lifecycle.endedPeriod,
      bothOrdinaryPeriodsEnded: lifecycle.bothOrdinaryPeriodsEnded,
    );
  }
  return _unresolved(
    TemporalUnresolvedReason.lifecycleIncomplete,
    historicalElapsed: historicalLastProvenActiveElapsed,
    historicalPeriod: historicalLastProvenPeriod,
  );
}

TemporalDisplayState _running({
  required PeriodIdentity period,
  required ActivePeriodElapsedProjection elapsed,
  required MatchFormatClockContext format,
  required TemporalEvidence? periodAnchor,
  required Duration? historicalLastProvenActiveElapsed,
  required PeriodIdentity? historicalLastProvenPeriod,
}) {
  if (_anchorCorrupted(periodAnchor)) {
    return _unresolved(
      TemporalUnresolvedReason.corruption,
      historicalElapsed: historicalLastProvenActiveElapsed,
      provenPeriod: period,
    );
  }
  if (elapsed.temporalTrust != ProjectionTrust.trusted) {
    return _unresolved(
      TemporalUnresolvedReason.conflict,
      historicalElapsed: historicalLastProvenActiveElapsed,
      provenPeriod: period,
    );
  }
  if (elapsed.formalSuspensionActive || elapsed.periodEnded) {
    return _unresolved(
      TemporalUnresolvedReason.conflict,
      historicalElapsed: historicalLastProvenActiveElapsed,
      provenPeriod: period,
    );
  }
  if (elapsed.activePeriod != null && elapsed.activePeriod != period) {
    return _unresolved(
      TemporalUnresolvedReason.conflict,
      historicalElapsed: historicalLastProvenActiveElapsed,
      historicalPeriod: historicalLastProvenPeriod,
    );
  }

  final coordinate = format.coordinateFor(period);
  if (coordinate == null &&
      elapsed.continuity != TemporalContinuityStatus.continuityUnresolved) {
    return _unresolved(
      TemporalUnresolvedReason.missingNominalBase,
      historicalElapsed: historicalLastProvenActiveElapsed,
      provenPeriod: period,
    );
  }

  switch (elapsed.continuity) {
    case TemporalContinuityStatus.exactContinuity:
      final active = elapsed.exactElapsed;
      if (active == null || coordinate == null) {
        return _unresolved(
          coordinate == null
              ? TemporalUnresolvedReason.missingNominalBase
              : TemporalUnresolvedReason.continuityUnresolved,
          historicalElapsed: historicalLastProvenActiveElapsed,
          provenPeriod: period,
        );
      }
      if (!_exactAnchor(periodAnchor)) {
        return _unresolved(
          periodAnchor == null || periodAnchor.monotonicElapsed == null
              ? TemporalUnresolvedReason.missingAnchor
              : TemporalUnresolvedReason.continuityUnresolved,
          historicalElapsed: historicalLastProvenActiveElapsed,
          provenPeriod: period,
        );
      }
      return RunningTrusted(
        period: period,
        nominalBase: coordinate.nominalBase,
        activeElapsed: active,
        footballTime: coordinate.nominalBase + active,
        addedTime: _addedTime(
          exactActiveElapsed: active,
          nominalLength: coordinate.nominalLength,
        ),
      );
    case TemporalContinuityStatus.boundedContinuity:
      if (elapsed.exactElapsed != null || coordinate == null) {
        return _unresolved(
          elapsed.exactElapsed != null
              ? TemporalUnresolvedReason.conflict
              : TemporalUnresolvedReason.missingNominalBase,
          historicalElapsed: historicalLastProvenActiveElapsed,
          provenPeriod: period,
        );
      }
      final lower = elapsed.elapsedLowerBound;
      final upper = elapsed.elapsedUpperBound;
      if (lower == null || upper == null || lower > upper) {
        return _unresolved(
          TemporalUnresolvedReason.continuityUnresolved,
          historicalElapsed: historicalLastProvenActiveElapsed,
          provenPeriod: period,
        );
      }
      return RunningBounded(
        period: period,
        nominalBase: coordinate.nominalBase,
        activeElapsedLowerBound: lower,
        activeElapsedUpperBound: upper,
        footballTimeLowerBound: coordinate.nominalBase + lower,
        footballTimeUpperBound: coordinate.nominalBase + upper,
        addedTime: AddedTimeDisplayContext.absent,
      );
    case TemporalContinuityStatus.continuityUnresolved:
      return _unresolved(
        periodAnchor == null || periodAnchor.monotonicElapsed == null
            ? TemporalUnresolvedReason.missingAnchor
            : TemporalUnresolvedReason.continuityUnresolved,
        historicalElapsed: historicalLastProvenActiveElapsed,
        provenPeriod: period,
      );
  }
}

TemporalDisplayState _suspended({
  required PeriodIdentity period,
  required TemporalMatchProjection lifecycle,
  required ActivePeriodElapsedProjection elapsed,
  required MatchFormatClockContext format,
  required TemporalEvidence? periodAnchor,
  required TemporalEvidence? suspensionBoundary,
  required Duration? historicalLastProvenActiveElapsed,
  required PeriodIdentity? historicalLastProvenPeriod,
}) {
  if (_anchorCorrupted(periodAnchor) || _anchorCorrupted(suspensionBoundary)) {
    return _unresolved(
      TemporalUnresolvedReason.corruption,
      historicalElapsed: historicalLastProvenActiveElapsed,
      provenPeriod: period,
    );
  }
  if (elapsed.temporalTrust != ProjectionTrust.trusted) {
    return _unresolved(
      TemporalUnresolvedReason.conflict,
      historicalElapsed: historicalLastProvenActiveElapsed,
      provenPeriod: period,
    );
  }
  final coordinate = format.coordinateFor(period);
  if (coordinate == null) {
    return _unresolved(
      TemporalUnresolvedReason.missingNominalBase,
      historicalElapsed: historicalLastProvenActiveElapsed,
      provenPeriod: period,
    );
  }
  if (elapsed.periodEnded || lifecycle.activePeriod != period) {
    return _unresolved(
      TemporalUnresolvedReason.conflict,
      historicalElapsed: historicalLastProvenActiveElapsed,
      provenPeriod: period,
    );
  }

  final SuspensionElapsed frozen;
  final AddedTimeDisplayContext addedTime;
  switch (elapsed.continuity) {
    case TemporalContinuityStatus.exactContinuity:
      final active = elapsed.exactElapsed;
      if (active == null || elapsed.formalSuspensionActive == false) {
        frozen = const UnavailableSuspensionElapsed();
        addedTime = AddedTimeDisplayContext.absent;
      } else {
        frozen = ExactSuspensionElapsed(
          activeElapsed: active,
          footballTime: coordinate.nominalBase + active,
        );
        addedTime = _addedTime(
          exactActiveElapsed: active,
          nominalLength: coordinate.nominalLength,
        );
      }
    case TemporalContinuityStatus.boundedContinuity:
      if (elapsed.exactElapsed != null) {
        return _unresolved(
          TemporalUnresolvedReason.conflict,
          historicalElapsed: historicalLastProvenActiveElapsed,
          provenPeriod: period,
        );
      }
      final lower = elapsed.elapsedLowerBound;
      final upper = elapsed.elapsedUpperBound;
      if (lower == null || upper == null || lower > upper) {
        frozen = const UnavailableSuspensionElapsed();
        addedTime = AddedTimeDisplayContext.absent;
      } else {
        frozen = BoundedSuspensionElapsed(
          activeElapsedLowerBound: lower,
          activeElapsedUpperBound: upper,
          footballTimeLowerBound: coordinate.nominalBase + lower,
          footballTimeUpperBound: coordinate.nominalBase + upper,
        );
        addedTime = AddedTimeDisplayContext.absent;
      }
    case TemporalContinuityStatus.continuityUnresolved:
      frozen = const UnavailableSuspensionElapsed();
      addedTime = AddedTimeDisplayContext.absent;
  }

  return SuspendedTrusted(
    period: period,
    nominalBase: coordinate.nominalBase,
    elapsed: frozen,
    suspensionEvidenceId: suspensionBoundary?.evidenceId,
    addedTime: addedTime,
  );
}

Unresolved? _blocked({
  required TemporalMatchProjection lifecycle,
  required MatchProjectionState projection,
  required Duration? historicalLastProvenActiveElapsed,
  required PeriodIdentity? historicalLastProvenPeriod,
}) {
  final temporal = projection.trustFor(ProjectionFacet.temporal);
  final authority = projection.trustFor(ProjectionFacet.authority);
  final historical = _unresolved(
    TemporalUnresolvedReason.conflict,
    historicalElapsed: historicalLastProvenActiveElapsed,
    historicalPeriod: historicalLastProvenPeriod,
  );

  if (temporal == ProjectionTrust.conflicted ||
      authority == ProjectionTrust.conflicted ||
      lifecycle.periodEndAmbiguous) {
    return historical;
  }
  if (temporal != ProjectionTrust.trusted &&
      projection.unsupportedSemanticRecordIds.isNotEmpty) {
    return _unresolved(
      TemporalUnresolvedReason.unsupportedSchema,
      historicalElapsed: historicalLastProvenActiveElapsed,
      historicalPeriod: historicalLastProvenPeriod,
    );
  }
  if (authority != ProjectionTrust.trusted) {
    if (projection.committedRecordIds.isEmpty) {
      return _unresolved(
        TemporalUnresolvedReason.lifecycleIncomplete,
        historicalElapsed: historicalLastProvenActiveElapsed,
        historicalPeriod: historicalLastProvenPeriod,
      );
    }
    return _unresolved(
      TemporalUnresolvedReason.staleAuthority,
      historicalElapsed: historicalLastProvenActiveElapsed,
      historicalPeriod: historicalLastProvenPeriod,
    );
  }
  if (temporal != ProjectionTrust.trusted) {
    return _unresolved(
      TemporalUnresolvedReason.lifecycleIncomplete,
      historicalElapsed: historicalLastProvenActiveElapsed,
      historicalPeriod: historicalLastProvenPeriod,
    );
  }
  return null;
}

bool _lineageUnreadable(TemporalMatchProjection lifecycle) {
  return lifecycle.matchStarted &&
      lifecycle.activePeriod == null &&
      lifecycle.endedPeriod == null &&
      !lifecycle.periodEndAmbiguous &&
      !lifecycle.intervalActive &&
      !lifecycle.temporallyIncomplete &&
      !lifecycle.formallySuspended &&
      !lifecycle.matchNormallyEnded &&
      !lifecycle.matchAbandoned;
}

bool _anchorCorrupted(TemporalEvidence? anchor) {
  if (anchor == null) return false;
  final lower = anchor.monotonicElapsed;
  final upper = anchor.monotonicUpperBound;
  if (lower != null && lower.isNegative) return true;
  if (upper != null && upper.isNegative) return true;
  if (upper != null && lower == null) return true;
  if (upper != null && lower != null && upper < lower) return true;
  return false;
}

bool _exactAnchor(TemporalEvidence? anchor) {
  return anchor != null &&
      anchor.monotonicElapsed != null &&
      !anchor.isInterval &&
      !_anchorCorrupted(anchor);
}

AddedTimeDisplayContext _addedTime({
  required Duration exactActiveElapsed,
  required Duration nominalLength,
}) {
  final beyond = exactActiveElapsed - nominalLength;
  return AddedTimeDisplayContext(
    suggestion: null,
    refereeDecision: null,
    publicIndication: const PublicIndicationUnsupported(),
    elapsedBeyondNominal:
        beyond > Duration.zero ? ElapsedBeyondNominal(beyond) : null,
  );
}

Unresolved _unresolved(
  TemporalUnresolvedReason reason, {
  Duration? historicalElapsed,
  PeriodIdentity? historicalPeriod,
  PeriodIdentity? provenPeriod,
}) {
  return Unresolved(
    reason: reason,
    lastProvenActiveElapsed: historicalElapsed,
    lastProvenPeriod: provenPeriod ?? historicalPeriod,
  );
}
