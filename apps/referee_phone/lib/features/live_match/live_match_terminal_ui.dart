import 'package:forref_match_core/forref_match_core.dart';
import 'package:referee_phone/l10n/app_localizations.dart';

/// Whether the End match action may be shown. Projection-only; not capture authority.
bool showEndMatchAction({
  required NormalMatchEndEligibility? eligibility,
  required bool matchNormallyEnded,
  required bool matchEndPending,
}) {
  return eligibility == NormalMatchEndEligibility.eligible &&
      !matchNormallyEnded;
}

/// Whether to show a blocked-terminal explanation instead of the action.
bool showTerminalBlockedReason({
  required NormalMatchEndEligibility? eligibility,
  required bool matchNormallyEnded,
  required bool matchStarted,
}) {
  if (!matchStarted || matchNormallyEnded || eligibility == null) {
    return false;
  }
  return eligibility != NormalMatchEndEligibility.eligible;
}

String? terminalEligibilityMessage(
  AppLocalizations l10n,
  NormalMatchEndEligibility eligibility,
) {
  return switch (eligibility) {
    NormalMatchEndEligibility.eligible => null,
    NormalMatchEndEligibility.blockedAdditionalPlayingPhase =>
      l10n.terminalBlockedAdditionalPlayingPhase,
    NormalMatchEndEligibility.blockedPhaseDispositionUnresolved =>
      l10n.terminalBlockedPhaseDispositionUnresolved,
    NormalMatchEndEligibility.blockedActivePeriod =>
      l10n.terminalBlockedActivePeriod,
    NormalMatchEndEligibility.blockedOpenSuspension =>
      l10n.terminalBlockedOpenSuspension,
    NormalMatchEndEligibility.blockedAbandoned => l10n.terminalBlockedAbandoned,
    NormalMatchEndEligibility.blockedAlreadyEnded =>
      l10n.terminalBlockedAlreadyEnded,
    NormalMatchEndEligibility.blockedAmbiguousLineage =>
      l10n.terminalBlockedAmbiguousLineage,
    NormalMatchEndEligibility.blockedNoCompletedPlayingPhase =>
      l10n.terminalBlockedNoCompletedPlayingPhase,
  };
}
