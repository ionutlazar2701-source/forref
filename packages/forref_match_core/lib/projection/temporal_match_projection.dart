import '../match_record.dart';
import '../record_kind.dart';
import '../relationships.dart';
import '../semantics/match_record_semantic_type.dart';
import '../semantics/v1_semantic_payload.dart';
import 'match_projection_state.dart';
import 'projection_trust.dart';

/// Disposable temporal facts rebuilt from committed records.
///
/// [matchStarted] and [activePeriod] are projection outputs. They are not
/// stored as authority and they do not advance a match clock.
final class TemporalMatchProjection {
  const TemporalMatchProjection({
    required this.matchStarted,
    required this.activePeriod,
    required this.endedPeriod,
    required this.periodEndAmbiguous,
    required this.intervalActive,
    required this.temporallyIncomplete,
    required this.formallySuspended,
    this.endedPeriods = const [],
    this.bothOrdinaryPeriodsEnded = false,
    this.matchNormallyEnded = false,
  });

  static const empty = TemporalMatchProjection(
    matchStarted: false,
    activePeriod: null,
    endedPeriod: null,
    periodEndAmbiguous: false,
    intervalActive: false,
    temporallyIncomplete: false,
    formallySuspended: false,
  );

  /// Authoritative match-start truth from a trusted `MATCH_STARTED` record.
  final bool matchStarted;

  /// Unfinished period whose `PERIOD_STARTED` causally depends on that match start.
  final PeriodIdentity? activePeriod;

  /// Latest ended period in the chain.
  ///
  /// While a later period is active this is the previous period. After every
  /// started period has ended, this is the last one. It is not match completion.
  final PeriodIdentity? endedPeriod;

  /// Every period in the chain that has one valid end.
  final List<PeriodIdentity> endedPeriods;

  /// Periods 1 and 2 have both ended. This is not match completion.
  final bool bothOrdinaryPeriodsEnded;

  /// One valid `MATCH_ENDED` follows the final completed playing period.
  ///
  /// Not fixture validation, a final result, or a completed shoot-out.
  final bool matchNormallyEnded;

  /// More than one end claims the same period lineage.
  final bool periodEndAmbiguous;

  /// Period 1 has ended and Period 2 has not started. The match is not terminal.
  ///
  /// Disposable projection only. A later ended period does not reopen it.
  /// Not a durable match state or Match Record.
  final bool intervalActive;

  /// Match start is committed and trusted, and no active period is.
  final bool temporallyIncomplete;

  /// One active period has an open formal suspension. A resumption closes it.
  ///
  /// This is rebuilt from records. It is not a stored match-state row.
  final bool formallySuspended;

  static TemporalMatchProjection derive({
    required MatchProjectionState projection,
    required List<MatchRecord> records,
  }) {
    if (projection.trustFor(ProjectionFacet.temporal) != ProjectionTrust.trusted) {
      return empty;
    }

    final sorted = [...records]..sort(deterministicRecordOrder);
    MatchRecord? matchStart;
    var matchStartCount = 0;
    for (final record in sorted) {
      if (!isTemporalTransition(record, V1SemanticTypeCode.matchStarted)) {
        continue;
      }
      matchStartCount++;
      matchStart ??= record;
    }
    if (matchStartCount != 1 || matchStart == null) return empty;

    final lineage = periodLineage(records: sorted);
    if (lineage.starts.isEmpty && !lineage.ambiguous) {
      return const TemporalMatchProjection(
        matchStarted: true,
        activePeriod: null,
        endedPeriod: null,
        periodEndAmbiguous: false,
        intervalActive: false,
        temporallyIncomplete: true,
        formallySuspended: false,
      );
    }
    if (lineage.ambiguous) {
      return const TemporalMatchProjection(
        matchStarted: true,
        activePeriod: null,
        endedPeriod: null,
        periodEndAmbiguous: false,
        intervalActive: false,
        temporallyIncomplete: false,
        formallySuspended: false,
      );
    }
    if (lineage.activeStart == null) {
      final normallyEnded = _matchNormallyEnded(sorted, lineage);
      return TemporalMatchProjection(
        matchStarted: true,
        activePeriod: null,
        endedPeriod: lineage.latestEnded,
        periodEndAmbiguous: lineage.endAmbiguous,
        intervalActive:
            lineage.intervalActive && !_matchAbandoned(sorted) && !normallyEnded,
        temporallyIncomplete: false,
        formallySuspended: false,
        endedPeriods: lineage.endedPeriods,
        bothOrdinaryPeriodsEnded: lineage.bothOrdinaryPeriodsEnded,
        matchNormallyEnded: normallyEnded,
      );
    }
    final activePeriod =
        (lineage.activeStart!.payload as TemporalTransitionPayload).period;
    final history = findSuspensionHistory(
      records: sorted,
      activePeriod: activePeriod,
    );
    return TemporalMatchProjection(
      matchStarted: true,
      activePeriod: activePeriod,
      endedPeriod: lineage.latestEnded,
      periodEndAmbiguous: false,
      intervalActive: false,
      temporallyIncomplete: false,
      formallySuspended: history.formallySuspended,
      endedPeriods: lineage.endedPeriods,
      bothOrdinaryPeriodsEnded: false,
    );
  }
}

bool _matchNormallyEnded(List<MatchRecord> records, PeriodLineage lineage) {
  if (lineage.ambiguous ||
      lineage.endAmbiguous ||
      lineage.activeStart != null ||
      lineage.endedPeriods.isEmpty ||
      _matchAbandoned(records)) {
    return false;
  }
  final ended = [
    for (final record in records)
      if (isTemporalTransition(record, V1SemanticTypeCode.matchEnded)) record,
  ];
  if (ended.length != 1) return false;
  final periodEnd = findPeriodEnd(
    records: records,
    period: lineage.endedPeriods.last,
  );
  final end = periodEnd.record;
  if (periodEnd.ambiguous || end == null) return false;
  return ended.single.relationships.any(
    (link) => link is CausalDependency && link.targetRecordId == end.recordId,
  );
}

bool _matchAbandoned(List<MatchRecord> records) {
  for (final record in records) {
    if (isTemporalTransition(record, V1SemanticTypeCode.matchAbandoned)) {
      return true;
    }
  }
  return false;
}

/// Ordered period starts that follow match start, then each previous period end.
///
/// A later period is in the chain only when it causally targets that end.
/// A start outside the chain makes [PeriodLineage.ambiguous].
final class PeriodLineage {
  const PeriodLineage({
    required this.starts,
    required this.activeStart,
    required this.latestEnded,
    required this.ambiguous,
    required this.endAmbiguous,
    required this.intervalActive,
    this.endedPeriods = const [],
    this.bothOrdinaryPeriodsEnded = false,
  });

  static const none = PeriodLineage(
    starts: [],
    activeStart: null,
    latestEnded: null,
    ambiguous: false,
    endAmbiguous: false,
    intervalActive: false,
  );

  final List<MatchRecord> starts;
  final MatchRecord? activeStart;
  final PeriodIdentity? latestEnded;
  final bool ambiguous;
  final bool endAmbiguous;

  /// Period 1 has one end and Period 2 has not started.
  final bool intervalActive;

  final List<PeriodIdentity> endedPeriods;

  /// Periods 1 and 2 have both ended. Not match completion.
  final bool bothOrdinaryPeriodsEnded;
}

PeriodLineage periodLineage({required List<MatchRecord> records}) {
  final sorted = [...records]..sort(deterministicRecordOrder);
  MatchRecord? matchStart;
  var matchStartCount = 0;
  for (final record in sorted) {
    if (!isTemporalTransition(record, V1SemanticTypeCode.matchStarted)) {
      continue;
    }
    matchStartCount++;
    matchStart ??= record;
  }
  if (matchStartCount != 1 || matchStart == null) return PeriodLineage.none;

  final periodStarts = <MatchRecord>[];
  for (final record in sorted) {
    final payload = record.payload;
    if (isTemporalTransition(record, V1SemanticTypeCode.periodStarted) &&
        payload is TemporalTransitionPayload &&
        payload.period != null) {
      periodStarts.add(record);
    }
  }
  final firsts = [
    for (final start in periodStarts)
      if ((start.payload as TemporalTransitionPayload).period!.index == 1 &&
          _dependsOn(start, matchStart.recordId))
        start,
  ];
  if (firsts.length > 1) {
    return const PeriodLineage(
      starts: [],
      activeStart: null,
      latestEnded: null,
      ambiguous: true,
      endAmbiguous: false,
      intervalActive: false,
    );
  }
  if (firsts.isEmpty) return PeriodLineage.none;

  final chain = <MatchRecord>[firsts.single];
  var endAmbiguous = false;
  while (true) {
    final ends = _endsTargeting(sorted, chain.last);
    if (ends.length > 1) {
      endAmbiguous = true;
      break;
    }
    if (ends.isEmpty) break;
    final nextIndex =
        (chain.last.payload as TemporalTransitionPayload).period!.index + 1;
    final nexts = [
      for (final start in periodStarts)
        if ((start.payload as TemporalTransitionPayload).period!.index ==
                nextIndex &&
            _dependsOn(start, ends.single.recordId))
          start,
    ];
    if (nexts.length > 1) {
      return const PeriodLineage(
        starts: [],
        activeStart: null,
        latestEnded: null,
        ambiguous: true,
        endAmbiguous: false,
        intervalActive: false,
      );
    }
    if (nexts.isEmpty) break;
    chain.add(nexts.single);
  }

  final chainIds = {for (final start in chain) start.recordId};
  if (periodStarts.any((start) => !chainIds.contains(start.recordId))) {
    return const PeriodLineage(
      starts: [],
      activeStart: null,
      latestEnded: null,
      ambiguous: true,
      endAmbiguous: false,
      intervalActive: false,
    );
  }

  final lastEnds = _endsTargeting(sorted, chain.last);
  final lastOpen = !endAmbiguous && lastEnds.isEmpty;
  final activeStart = lastOpen ? chain.last : null;
  final endedRecords = lastOpen || endAmbiguous
      ? chain.take(chain.length - 1)
      : chain;
  final endedPeriods = [
    for (final start in endedRecords)
      (start.payload as TemporalTransitionPayload).period!,
  ];
  PeriodIdentity? latestEnded;
  if (!lastOpen) {
    latestEnded = (chain.last.payload as TemporalTransitionPayload).period;
  } else if (chain.length > 1) {
    latestEnded =
        (chain[chain.length - 2].payload as TemporalTransitionPayload).period;
  }
  final bothOrdinaryPeriodsEnded = !endAmbiguous &&
      activeStart == null &&
      endedPeriods.length == 2 &&
      endedPeriods.first.index == 1 &&
      endedPeriods.last.index == 2;
  return PeriodLineage(
    starts: chain,
    activeStart: activeStart,
    latestEnded: latestEnded,
    ambiguous: false,
    endAmbiguous: endAmbiguous,
    intervalActive: !endAmbiguous &&
        activeStart == null &&
        endedPeriods.length == 1 &&
        endedPeriods.single.index == 1,
    endedPeriods: endedPeriods,
    bothOrdinaryPeriodsEnded: bothOrdinaryPeriodsEnded,
  );
}

bool _dependsOn(MatchRecord record, String targetId) {
  return record.relationships.any(
    (link) => link is CausalDependency && link.targetRecordId == targetId,
  );
}

List<MatchRecord> _endsTargeting(List<MatchRecord> records, MatchRecord start) {
  final index = (start.payload as TemporalTransitionPayload).period!.index;
  final ends = <MatchRecord>[];
  for (final record in records) {
    final payload = record.payload;
    if (!isTemporalTransition(record, V1SemanticTypeCode.periodEnded) ||
        payload is! TemporalTransitionPayload ||
        payload.period?.index != index ||
        !_dependsOn(record, start.recordId)) {
      continue;
    }
    ends.add(record);
  }
  return ends;
}

/// One `PERIOD_ENDED` that causally follows the period start.
final class PeriodEndMatch {
  const PeriodEndMatch.none()
      : record = null,
        ambiguous = false;

  const PeriodEndMatch.ambiguous()
      : record = null,
        ambiguous = true;

  const PeriodEndMatch.one(this.record) : ambiguous = false;

  final MatchRecord? record;
  final bool ambiguous;
}

/// The period end tied to the period start. Timestamp proximity does not count.
PeriodEndMatch findPeriodEnd({
  required List<MatchRecord> records,
  required PeriodIdentity? period,
}) {
  if (period == null) return const PeriodEndMatch.none();
  final periodStart = anchoredPeriodStart(records, period);
  if (periodStart == null) return const PeriodEndMatch.none();

  final sorted = [...records]..sort(deterministicRecordOrder);
  final ends = <MatchRecord>[];
  for (final record in sorted) {
    final payload = record.payload;
    if (!isTemporalTransition(record, V1SemanticTypeCode.periodEnded) ||
        payload is! TemporalTransitionPayload ||
        payload.period?.index != period.index) {
      continue;
    }
    final dependsOnPeriod = record.relationships.any(
      (link) =>
          link is CausalDependency &&
          link.targetRecordId == periodStart.recordId,
    );
    if (dependsOnPeriod) ends.add(record);
  }
  if (ends.isEmpty) return const PeriodEndMatch.none();
  if (ends.length > 1) return const PeriodEndMatch.ambiguous();
  return PeriodEndMatch.one(ends.single);
}

/// Period start in the match lineage. Period 1 follows match start.
/// A later period follows the previous period end.
MatchRecord? anchoredPeriodStart(
  List<MatchRecord> records,
  PeriodIdentity period,
) {
  final lineage = periodLineage(records: records);
  if (lineage.ambiguous) return null;
  for (final start in lineage.starts) {
    final payload = start.payload;
    if (payload is TemporalTransitionPayload &&
        payload.period?.index == period.index) {
      return start;
    }
  }
  return null;
}

/// One formal suspension and the resumption that closes it, if any.
final class SuspensionCycle {
  const SuspensionCycle({
    required this.start,
    this.end,
    this.endAmbiguous = false,
  });

  final MatchRecord start;
  final MatchRecord? end;
  final bool endAmbiguous;

  bool get open => end == null && !endAmbiguous;

  bool get closed => end != null && !endAmbiguous;
}

/// Ordered formal-suspension history of one period.
///
/// [overlapping] means a later start exists while an earlier one is still open.
final class SuspensionHistory {
  const SuspensionHistory({
    required this.cycles,
    required this.overlapping,
  });

  static const empty = SuspensionHistory(cycles: [], overlapping: false);

  final List<SuspensionCycle> cycles;
  final bool overlapping;

  SuspensionCycle? get openCycle {
    if (overlapping || cycles.isEmpty) return null;
    final last = cycles.last;
    return last.open ? last : null;
  }

  /// An open suspension, or an overlapping pair that must not be treated as play.
  bool get formallySuspended => openCycle != null || overlapping;
}

/// Formal suspension starts that causally follow the period start, in commit order.
SuspensionHistory findSuspensionHistory({
  required List<MatchRecord> records,
  required PeriodIdentity? activePeriod,
}) {
  if (activePeriod == null) return SuspensionHistory.empty;
  final periodStart = anchoredPeriodStart(records, activePeriod);
  if (periodStart == null) return SuspensionHistory.empty;

  final sorted = [...records]..sort(deterministicRecordOrder);
  final starts = <MatchRecord>[];
  for (final record in sorted) {
    final payload = record.payload;
    if (!isTemporalTransition(
          record,
          V1SemanticTypeCode.temporarySuspensionStarted,
        ) ||
        payload is! TemporalTransitionPayload ||
        payload.period?.index != activePeriod.index) {
      continue;
    }
    final dependsOnPeriod = record.relationships.any(
      (link) =>
          link is CausalDependency &&
          link.targetRecordId == periodStart.recordId,
    );
    if (dependsOnPeriod) starts.add(record);
  }
  if (starts.isEmpty) return SuspensionHistory.empty;

  final cycles = <SuspensionCycle>[];
  var overlapping = false;
  for (final start in starts) {
    if (cycles.isNotEmpty && !cycles.last.closed) overlapping = true;
    final ends = <MatchRecord>[];
    for (final record in sorted) {
      final payload = record.payload;
      if (!isTemporalTransition(
            record,
            V1SemanticTypeCode.temporarySuspensionEnded,
          ) ||
          payload is! TemporalTransitionPayload ||
          payload.period?.index != activePeriod.index) {
        continue;
      }
      final closesStart = record.relationships.any(
        (link) =>
            link is CausalDependency && link.targetRecordId == start.recordId,
      );
      if (closesStart) ends.add(record);
    }
    if (ends.length > 1) {
      cycles.add(SuspensionCycle(start: start, endAmbiguous: true));
    } else if (ends.length == 1) {
      cycles.add(SuspensionCycle(start: start, end: ends.single));
    } else {
      cycles.add(SuspensionCycle(start: start));
    }
  }
  if (cycles.where((cycle) => cycle.open).length > 1) overlapping = true;
  return SuspensionHistory(cycles: cycles, overlapping: overlapping);
}

/// The current open formal suspension.
///
/// Closed historical cycles are not returned here. [ambiguous] means the
/// open lineage is not a single suspension.
final class FormalSuspensionStart {
  const FormalSuspensionStart.none()
      : record = null,
        end = null,
        ambiguous = false,
        endAmbiguous = false;

  const FormalSuspensionStart.ambiguous()
      : record = null,
        end = null,
        ambiguous = true,
        endAmbiguous = false;

  const FormalSuspensionStart.one(
    this.record, {
    this.end,
    this.endAmbiguous = false,
  }) : ambiguous = false;

  final MatchRecord? record;
  final MatchRecord? end;
  final bool ambiguous;
  final bool endAmbiguous;

  /// Open formal suspension. A closed suspension is not active.
  bool get active =>
      end == null && !endAmbiguous && (ambiguous || record != null);

  /// One start and one resumption on that start.
  bool get closed =>
      record != null && end != null && !ambiguous && !endAmbiguous;
}

FormalSuspensionStart findFormalSuspensionStart({
  required List<MatchRecord> records,
  required PeriodIdentity? activePeriod,
}) {
  final history = findSuspensionHistory(
    records: records,
    activePeriod: activePeriod,
  );
  if (history.overlapping) return const FormalSuspensionStart.ambiguous();
  final open = history.openCycle;
  if (open == null) return const FormalSuspensionStart.none();
  if (open.endAmbiguous) {
    return FormalSuspensionStart.one(open.start, endAmbiguous: true);
  }
  return FormalSuspensionStart.one(open.start);
}

bool isTemporalTransition(MatchRecord record, V1SemanticTypeCode code) {
  final payload = record.payload;
  return record.recordKind == RecordKind.temporalFact &&
      payload is TemporalTransitionPayload &&
      payload.semanticType == code;
}

int deterministicRecordOrder(MatchRecord a, MatchRecord b) {
  final origin = a.originDeviceId.compareTo(b.originDeviceId);
  if (origin != 0) return origin;
  final sequence = a.originSequence.compareTo(b.originSequence);
  if (sequence != 0) return sequence;
  return a.recordId.compareTo(b.recordId);
}
