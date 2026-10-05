import 'v1_semantic_payload.dart';

/// Reads the explicit playing-phase decision from competition rules.
///
/// Period count, goal totals, thresholds, and a later penalty shoot-out are
/// not inputs. A missing rules context stays unresolved.
AdditionalPlayingPhaseDisposition resolveAdditionalPlayingPhase(
  CompetitionRulesContext? rules,
) {
  if (rules == null) return AdditionalPlayingPhaseDisposition.unresolved;
  return rules.additionalPlayingPhase;
}
