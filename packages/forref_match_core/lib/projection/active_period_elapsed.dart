import '../match_record.dart';
import '../semantics/v1_semantic_payload.dart';
import '../temporal.dart';
import 'match_projection_state.dart';
import 'projection_trust.dart';
import 'temporal_match_projection.dart';

/// How far the active-period elapsed reading can be trusted.
///
/// This is continuity of the evidence domain, not platform certification
/// and not a stored match clock.
enum TemporalContinuityStatus {
  exactContinuity,
  boundedContinuity,
  continuityUnresolved,
}

/// Disposable active-period elapsed display facts.
///
/// Nothing here is Match Memory. Reaching [regulationDisplayThreshold]
/// does not end a period.
final class ActivePeriodElapsedProjection {
  const ActivePeriodElapsedProjection({
    required this.activePeriod,
    required this.continuity,
    required this.temporalTrust,
    required this.exactElapsed,
    required this.elapsedLowerBound,
    required this.elapsedUpperBound,
    required this.precisionSafeToShow,
    required this.certified,
    required this.pastRegulationDisplayThreshold,
    required this.formalSuspensionActive,
    required this.suspensionStarted,
    required this.suspensionDurationOpen,
    required this.suspensionEnded,
    required this.suspensionDuration,
    required this.suspensionDurationLowerBound,
    required this.suspensionDurationUpperBound,
    required this.suspensionDurations,
    required this.playingSegments,
    required this.periodEnded,
  });

  static const unavailable = ActivePeriodElapsedProjection(
    activePeriod: null,
    continuity: TemporalContinuityStatus.continuityUnresolved,
    temporalTrust: ProjectionTrust.untrusted,
    exactElapsed: null,
    elapsedLowerBound: null,
    elapsedUpperBound: null,
    precisionSafeToShow: false,
    certified: false,
    pastRegulationDisplayThreshold: false,
    formalSuspensionActive: false,
    suspensionStarted: false,
    suspensionDurationOpen: false,
    suspensionEnded: false,
    suspensionDuration: null,
    suspensionDurationLowerBound: null,
    suspensionDurationUpperBound: null,
    suspensionDurations: <Duration?>[],
    playingSegments: <Duration?>[],
    periodEnded: false,
  );

  /// Display-only regulation mark. Not `PERIOD_ENDED` authority.
  static const regulationDisplayThreshold = Duration(minutes: 45);

  final PeriodIdentity? activePeriod;
  final TemporalContinuityStatus continuity;
  final ProjectionTrust temporalTrust;

  /// Set only for [TemporalContinuityStatus.exactContinuity].
  final Duration? exactElapsed;

  /// Set only for [TemporalContinuityStatus.boundedContinuity].
  final Duration? elapsedLowerBound;
  final Duration? elapsedUpperBound;

  /// Whole-second display is safe. This is not certification.
  final bool precisionSafeToShow;

  /// Always false in this window. Phone evidence is not certified.
  final bool certified;

  /// Exact elapsed has reached 45:00. The period stays active.
  final bool pastRegulationDisplayThreshold;

  /// A formal suspension start is authoritative for the active period.
  final bool formalSuspensionActive;

  /// At least one formal suspension start belongs to this period.
  ///
  /// Exact seconds can still be unavailable when boundary evidence is not.
  final bool suspensionStarted;

  /// Suspension has no end record. Its duration is not playing elapsed.
  final bool suspensionDurationOpen;

  /// A resumption record closes the formal suspension.
  final bool suspensionEnded;

  /// Exact duration when the period has one completed suspension interval.
  ///
  /// Several intervals stay in [suspensionDurations] and are not collapsed here.
  final Duration? suspensionDuration;

  /// Bounds for that single completed interval when it is not an exact second.
  final Duration? suspensionDurationLowerBound;
  final Duration? suspensionDurationUpperBound;

  /// Completed suspension intervals, in order. A null entry is not exact.
  final List<Duration?> suspensionDurations;

  /// Playing segments, in order. A null entry is not an exact segment.
  ///
  /// Their exact sum is [exactElapsed] only when every segment is exact.
  final List<Duration?> playingSegments;

  /// A `PERIOD_ENDED` record closed this period. Later samples do not advance it.
  final bool periodEnded;

  @override
  bool operator ==(Object other) {
    return other is ActivePeriodElapsedProjection &&
        activePeriod == other.activePeriod &&
        continuity == other.continuity &&
        temporalTrust == other.temporalTrust &&
        exactElapsed == other.exactElapsed &&
        elapsedLowerBound == other.elapsedLowerBound &&
        elapsedUpperBound == other.elapsedUpperBound &&
        precisionSafeToShow == other.precisionSafeToShow &&
        certified == other.certified &&
        pastRegulationDisplayThreshold ==
            other.pastRegulationDisplayThreshold &&
        formalSuspensionActive == other.formalSuspensionActive &&
        suspensionStarted == other.suspensionStarted &&
        suspensionDurationOpen == other.suspensionDurationOpen &&
        suspensionEnded == other.suspensionEnded &&
        suspensionDuration == other.suspensionDuration &&
        suspensionDurationLowerBound == other.suspensionDurationLowerBound &&
        suspensionDurationUpperBound == other.suspensionDurationUpperBound &&
        _sameDurations(suspensionDurations, other.suspensionDurations) &&
        _sameDurations(playingSegments, other.playingSegments) &&
        periodEnded == other.periodEnded;
  }

  @override
  int get hashCode => Object.hash(
        activePeriod,
        continuity,
        temporalTrust,
        exactElapsed,
        elapsedLowerBound,
        elapsedUpperBound,
        precisionSafeToShow,
        certified,
        pastRegulationDisplayThreshold,
        formalSuspensionActive,
        suspensionStarted,
        suspensionDurationOpen,
        suspensionEnded,
        suspensionDuration,
        suspensionDurationLowerBound,
        suspensionDurationUpperBound,
        Object.hashAll(suspensionDurations),
        Object.hashAll(playingSegments),
        periodEnded,
      );
}

/// Derives active-period elapsed from temporal authority and evidence.
///
/// Playing elapsed is the sum of playing segments only. Each formal suspension
/// interval is kept apart and is not played again. Wall-clock chronology is
/// not a segment. Any number of closed cycles uses the same segment walk.
ActivePeriodElapsedProjection deriveActivePeriodElapsed({
  required TemporalMatchProjection temporal,
  required MatchProjectionState projection,
  required List<MatchRecord> records,
  required TemporalEvidence? anchor,
  required TemporalEvidence? current,
  TemporalEvidence? suspensionBoundary,
  TemporalEvidence? resumptionAnchor,
  List<TemporalEvidence> recordedEvidence = const [],
}) {
  final trust = projection.trustFor(ProjectionFacet.temporal);
  final period = temporal.activePeriod ?? temporal.endedPeriod;
  final periodEnded =
      temporal.endedPeriod != null && temporal.activePeriod == null;
  final displayPeriod =
      temporal.intervalActive || temporal.bothOrdinaryPeriodsEnded
          ? null
          : period;
  if (!temporal.matchStarted ||
      period == null ||
      trust != ProjectionTrust.trusted) {
    return _unresolved(period, trust);
  }

  final history = findSuspensionHistory(
    records: records,
    activePeriod: period,
  );
  final periodRecord = anchoredPeriodStart(records, period);
  final anchorIds = periodRecord?.temporalContext?.evidenceIds ?? const [];
  TemporalEvidence? lookup(String? id) {
    if (id == null) return null;
    for (final item in recordedEvidence) {
      if (item.evidenceId == id) return item;
    }
    if (anchor?.evidenceId == id) return anchor;
    if (suspensionBoundary?.evidenceId == id) return suspensionBoundary;
    if (resumptionAnchor?.evidenceId == id) return resumptionAnchor;
    return null;
  }

  TemporalEvidence? evidenceFor(MatchRecord? record) {
    final ids = record?.temporalContext?.evidenceIds ?? const <String>[];
    if (ids.isEmpty) return null;
    final sample = lookup(ids.first);
    if (sample == null || !ids.contains(sample.evidenceId)) return null;
    return sample;
  }

  final trustedAnchor =
      anchorIds.isEmpty ? null : evidenceFor(periodRecord);
  final started = history.cycles.isNotEmpty;
  final suspended = history.formallySuspended;
  final durations = <Duration?>[];
  final durationSpans = <_ElapsedSpan>[];
  for (final cycle in history.cycles) {
    if (!cycle.closed) continue;
    final held = _span(evidenceFor(cycle.start), evidenceFor(cycle.end));
    durationSpans.add(held);
    durations.add(held.exact);
  }
  final single = durationSpans.length == 1 ? durationSpans.single : null;

  if (temporal.periodEndAmbiguous ||
      history.overlapping ||
      history.cycles.any((cycle) => cycle.endAmbiguous)) {
    return _unresolved(
      displayPeriod,
      trust,
      formalSuspensionActive: periodEnded ? false : suspended,
      suspensionStarted: started,
      suspensionDurationOpen: periodEnded
          ? false
          : history.cycles.any((cycle) => cycle.open),
      suspensionDurations: durations,
      periodEnded: periodEnded,
    );
  }

  final segments = <_ElapsedSpan>[];
  var cursor = trustedAnchor;
  for (final cycle in history.cycles) {
    segments.add(_span(cursor, evidenceFor(cycle.start)));
    if (cycle.open) break;
    cursor = evidenceFor(cycle.end);
  }
  final periodEnd = findPeriodEnd(records: records, period: period);
  if (periodEnded && (suspended || periodEnd.record == null)) {
    return _unresolved(
      displayPeriod,
      trust,
      suspensionStarted: started,
      suspensionDurations: durations,
      playingSegments: [for (final segment in segments) segment.exact],
      periodEnded: true,
    );
  }
  if (periodEnded) {
    segments.add(_span(cursor, evidenceFor(periodEnd.record)));
  } else if (!suspended) {
    segments.add(_span(cursor, current));
  }
  final played = _sumSpans(segments);
  return _fromSpan(
    period: displayPeriod,
    trust: trust,
    span: played,
    formalSuspensionActive: periodEnded ? false : suspended,
    suspensionStarted: started,
    suspensionDurationOpen: periodEnded ? false : history.openCycle != null,
    suspensionEnded: !suspended && history.cycles.any((cycle) => cycle.closed),
    suspensionDuration: single?.exact,
    suspensionDurationLowerBound: single?.lower,
    suspensionDurationUpperBound: single?.upper,
    suspensionDurations: durations,
    playingSegments: [for (final segment in segments) segment.exact],
    periodEnded: periodEnded,
  );
}

ActivePeriodElapsedProjection _fromSpan({
  required PeriodIdentity? period,
  required ProjectionTrust trust,
  required _ElapsedSpan span,
  bool formalSuspensionActive = false,
  bool suspensionStarted = false,
  bool suspensionDurationOpen = false,
  bool suspensionEnded = false,
  Duration? suspensionDuration,
  Duration? suspensionDurationLowerBound,
  Duration? suspensionDurationUpperBound,
  List<Duration?> suspensionDurations = const <Duration?>[],
  List<Duration?> playingSegments = const <Duration?>[],
  bool periodEnded = false,
}) {
  if (span.unresolved) {
    return _unresolved(
      period,
      trust,
      formalSuspensionActive: formalSuspensionActive,
      suspensionStarted: suspensionStarted,
      suspensionDurationOpen: suspensionDurationOpen,
      suspensionEnded: suspensionEnded,
      suspensionDuration: suspensionDuration,
      suspensionDurationLowerBound: suspensionDurationLowerBound,
      suspensionDurationUpperBound: suspensionDurationUpperBound,
      suspensionDurations: suspensionDurations,
      playingSegments: playingSegments,
      periodEnded: periodEnded,
    );
  }

  if (span.exact != null) {
    return ActivePeriodElapsedProjection(
      activePeriod: period,
      continuity: TemporalContinuityStatus.exactContinuity,
      temporalTrust: trust,
      exactElapsed: span.exact,
      elapsedLowerBound: null,
      elapsedUpperBound: null,
      precisionSafeToShow: true,
      certified: false,
      pastRegulationDisplayThreshold: span.exact! >=
          ActivePeriodElapsedProjection.regulationDisplayThreshold,
      formalSuspensionActive: formalSuspensionActive,
      suspensionStarted: suspensionStarted,
      suspensionDurationOpen: suspensionDurationOpen,
      suspensionEnded: suspensionEnded,
      suspensionDuration: suspensionDuration,
      suspensionDurationLowerBound: suspensionDurationLowerBound,
      suspensionDurationUpperBound: suspensionDurationUpperBound,
      suspensionDurations: suspensionDurations,
      playingSegments: playingSegments,
      periodEnded: periodEnded,
    );
  }

  return ActivePeriodElapsedProjection(
    activePeriod: period,
    continuity: TemporalContinuityStatus.boundedContinuity,
    temporalTrust: trust,
    exactElapsed: null,
    elapsedLowerBound: span.lower,
    elapsedUpperBound: span.upper,
    precisionSafeToShow: false,
    certified: false,
    pastRegulationDisplayThreshold: false,
    formalSuspensionActive: formalSuspensionActive,
    suspensionStarted: suspensionStarted,
    suspensionDurationOpen: suspensionDurationOpen,
    suspensionEnded: suspensionEnded,
    suspensionDuration: suspensionDuration,
    suspensionDurationLowerBound: suspensionDurationLowerBound,
    suspensionDurationUpperBound: suspensionDurationUpperBound,
    suspensionDurations: suspensionDurations,
    playingSegments: playingSegments,
    periodEnded: periodEnded,
  );
}

ActivePeriodElapsedProjection _unresolved(
  PeriodIdentity? period,
  ProjectionTrust trust, {
  bool formalSuspensionActive = false,
  bool suspensionStarted = false,
  bool suspensionDurationOpen = false,
  bool suspensionEnded = false,
  Duration? suspensionDuration,
  Duration? suspensionDurationLowerBound,
  Duration? suspensionDurationUpperBound,
  List<Duration?> suspensionDurations = const <Duration?>[],
  List<Duration?> playingSegments = const <Duration?>[],
  bool periodEnded = false,
}) {
  return ActivePeriodElapsedProjection(
    activePeriod: period,
    continuity: TemporalContinuityStatus.continuityUnresolved,
    temporalTrust: trust,
    exactElapsed: null,
    elapsedLowerBound: null,
    elapsedUpperBound: null,
    precisionSafeToShow: false,
    certified: false,
    pastRegulationDisplayThreshold: false,
    formalSuspensionActive: formalSuspensionActive,
    suspensionStarted: suspensionStarted,
    suspensionDurationOpen: suspensionDurationOpen,
    suspensionEnded: suspensionEnded,
    suspensionDuration: suspensionDuration,
    suspensionDurationLowerBound: suspensionDurationLowerBound,
    suspensionDurationUpperBound: suspensionDurationUpperBound,
    suspensionDurations: suspensionDurations,
    playingSegments: playingSegments,
    periodEnded: periodEnded,
  );
}

bool _sameDurations(List<Duration?> left, List<Duration?> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

final class _ElapsedSpan {
  const _ElapsedSpan.unresolved()
      : exact = null,
        lower = null,
        upper = null,
        unresolved = true;

  const _ElapsedSpan.exact(this.exact)
      : lower = null,
        upper = null,
        unresolved = false;

  const _ElapsedSpan.bounded(this.lower, this.upper)
      : exact = null,
        unresolved = false;

  final Duration? exact;
  final Duration? lower;
  final Duration? upper;
  final bool unresolved;
}

_ElapsedSpan _span(TemporalEvidence? start, TemporalEvidence? end) {
  if (start == null ||
      end == null ||
      start.continuityDomainId == null ||
      start.continuityDomainId != end.continuityDomainId ||
      start.monotonicElapsed == null ||
      end.monotonicElapsed == null) {
    return const _ElapsedSpan.unresolved();
  }

  final startLower = start.monotonicElapsed!;
  final startUpper = start.monotonicUpperBound ?? startLower;
  final endLower = end.monotonicElapsed!;
  final endUpper = end.monotonicUpperBound ?? endLower;
  if (startUpper < startLower || endUpper < endLower || endLower < startUpper) {
    return const _ElapsedSpan.unresolved();
  }

  final lower = endLower - startUpper;
  final upper = endUpper - startLower;
  if (start.isInterval || end.isInterval) {
    return _ElapsedSpan.bounded(lower, upper);
  }
  return _ElapsedSpan.exact(lower);
}

_ElapsedSpan _sumSpans(List<_ElapsedSpan> spans) {
  if (spans.isEmpty) return const _ElapsedSpan.exact(Duration.zero);
  var sum = spans.first;
  for (final span in spans.skip(1)) {
    sum = _addSpans(sum, span);
  }
  return sum;
}

_ElapsedSpan _addSpans(_ElapsedSpan base, _ElapsedSpan since) {
  if (base.unresolved || since.unresolved) {
    return const _ElapsedSpan.unresolved();
  }
  if (base.exact != null && since.exact != null) {
    return _ElapsedSpan.exact(base.exact! + since.exact!);
  }
  final baseLower = base.exact ?? base.lower!;
  final baseUpper = base.exact ?? base.upper!;
  final sinceLower = since.exact ?? since.lower!;
  final sinceUpper = since.exact ?? since.upper!;
  return _ElapsedSpan.bounded(baseLower + sinceLower, baseUpper + sinceUpper);
}
