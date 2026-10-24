import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/officiate/preparation_assessment.dart';

String preparationClaimLabel(AppLocalizations l10n, PreparationClaim claim) {
  return switch (claim) {
    PreparationClaim.needsAttention => l10n.needsAttention,
    PreparationClaim.matchSetupReady => l10n.matchSetupReady,
    PreparationClaim.readyToOfficiateOnThisPhone =>
      l10n.readyToOfficiateOnThisPhone,
    PreparationClaim.recordingAuthorityUnconfirmed =>
      l10n.recordingAuthorityUnconfirmed,
  };
}

String preparationBlockerLabel(
  AppLocalizations l10n,
  PreparationBlocker blocker,
) {
  return switch (blocker) {
    PreparationBlocker.homeTeamRequired => l10n.homeTeamRequired,
    PreparationBlocker.awayTeamRequired => l10n.awayTeamRequired,
    PreparationBlocker.halfLengthRequired => l10n.halfLengthRequired,
    PreparationBlocker.localRecordingUnavailable =>
      l10n.localRecordingUnavailable,
    PreparationBlocker.recordingAuthorityUnconfirmed =>
      l10n.recordingAuthorityUnconfirmed,
  };
}
