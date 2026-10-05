import '../match_record.dart';
import '../semantics/match_record_semantic_type.dart';
import '../semantics/v1_semantic_payload.dart';
import 'temporal_match_projection.dart';

/// Disposable gate for a future explicit `MATCH_ENDED` capture.
///
/// This is not capture authority and it does not write a Match Record.
enum NormalMatchEndEligibility {
  eligible,
  blockedAdditionalPlayingPhase,
  blockedPhaseDispositionUnresolved,
  blockedActivePeriod,
  blockedOpenSuspension,
  blockedAbandoned,
  blockedAlreadyEnded,
  blockedAmbiguousLineage,
  blockedNoCompletedPlayingPhase,
}

/// Whether the current lineage could accept a later normal match end.
///
/// [disposition] must already be the competition-rules decision.
/// Two ended periods do not supply that decision.
NormalMatchEndEligibility assessNormalMatchEnd({
  required List<MatchRecord> records,
  required AdditionalPlayingPhaseDisposition disposition,
}) {
  final lineage = periodLineage(records: records);
  if (lineage.ambiguous || lineage.endAmbiguous) {
    return NormalMatchEndEligibility.blockedAmbiguousLineage;
  }
  final abandoned = _has(records, V1SemanticTypeCode.matchAbandoned);
  final alreadyEnded = _has(records, V1SemanticTypeCode.matchEnded);
  if (abandoned && alreadyEnded) {
    return NormalMatchEndEligibility.blockedAmbiguousLineage;
  }
  if (abandoned) return NormalMatchEndEligibility.blockedAbandoned;
  if (alreadyEnded) return NormalMatchEndEligibility.blockedAlreadyEnded;

  final active = lineage.activeStart;
  if (active != null) {
    final period = (active.payload as TemporalTransitionPayload).period;
    final history = findSuspensionHistory(
      records: records,
      activePeriod: period,
    );
    if (history.formallySuspended) {
      return NormalMatchEndEligibility.blockedOpenSuspension;
    }
    return NormalMatchEndEligibility.blockedActivePeriod;
  }
  if (lineage.endedPeriods.isEmpty) {
    return NormalMatchEndEligibility.blockedNoCompletedPlayingPhase;
  }
  return switch (disposition) {
    AdditionalPlayingPhaseDisposition.additionalPlayingPhaseRequired =>
      NormalMatchEndEligibility.blockedAdditionalPlayingPhase,
    AdditionalPlayingPhaseDisposition.unresolved =>
      NormalMatchEndEligibility.blockedPhaseDispositionUnresolved,
    AdditionalPlayingPhaseDisposition.noneRequired =>
      NormalMatchEndEligibility.eligible,
  };
}

/// `PERIOD_ENDED` of the last completed period when no period is still active.
///
/// Null when the lineage cannot name one final playing phase.
MatchRecord? finalCompletedPeriodEnd({required List<MatchRecord> records}) {
  final lineage = periodLineage(records: records);
  if (lineage.ambiguous ||
      lineage.endAmbiguous ||
      lineage.activeStart != null ||
      lineage.endedPeriods.isEmpty) {
    return null;
  }
  final end = findPeriodEnd(
    records: records,
    period: lineage.endedPeriods.last,
  );
  if (end.ambiguous) return null;
  return end.record;
}

bool _has(List<MatchRecord> records, V1SemanticTypeCode code) {
  for (final record in records) {
    if (isTemporalTransition(record, code)) return true;
  }
  return false;
}
