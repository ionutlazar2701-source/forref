/// Derived preparation claim. This is not a stored sporting fact.
enum PreparationClaim {
  needsAttention,
  matchSetupReady,
  readyToOfficiateOnThisPhone,
  recordingAuthorityUnconfirmed,
}

enum PreparationBlocker {
  homeTeamRequired,
  awayTeamRequired,
  halfLengthRequired,
  localRecordingUnavailable,
  recordingAuthorityUnconfirmed,
}

/// Evidence-backed preparation result.
///
/// [canEnterLiveMatch] is the phone operating gate for the existing Live
/// Match entry. Optional crew, venue, competition, and squad names are not
/// blockers. Watch, network, and cloud state are not inputs.
final class PreparationAssessment {
  const PreparationAssessment({
    required this.claim,
    required this.blockers,
    required this.canEnterLiveMatch,
  });

  final PreparationClaim claim;
  final List<PreparationBlocker> blockers;
  final bool canEnterLiveMatch;

  bool get identityComplete =>
      !blockers.contains(PreparationBlocker.homeTeamRequired) &&
      !blockers.contains(PreparationBlocker.awayTeamRequired) &&
      !blockers.contains(PreparationBlocker.halfLengthRequired);
}

PreparationAssessment assessPreparation({
  required String homeName,
  required String awayName,
  required int? halfMinutes,
  required bool localStorageReady,
  required bool authorityKnown,
  required bool temporalEvidenceReady,
}) {
  final blockers = <PreparationBlocker>[
    if (homeName.trim().isEmpty) PreparationBlocker.homeTeamRequired,
    if (awayName.trim().isEmpty) PreparationBlocker.awayTeamRequired,
    if (halfMinutes == null || halfMinutes <= 0)
      PreparationBlocker.halfLengthRequired,
    if (!localStorageReady) PreparationBlocker.localRecordingUnavailable,
    if (!authorityKnown) PreparationBlocker.recordingAuthorityUnconfirmed,
  ];
  final identityComplete = homeName.trim().isNotEmpty &&
      awayName.trim().isNotEmpty &&
      halfMinutes != null &&
      halfMinutes > 0;
  final operatingProfile = localStorageReady && authorityKnown;
  final PreparationClaim claim;
  if (!authorityKnown) {
    claim = PreparationClaim.recordingAuthorityUnconfirmed;
  } else if (!operatingProfile || !identityComplete) {
    claim = PreparationClaim.needsAttention;
  } else if (!temporalEvidenceReady) {
    claim = PreparationClaim.matchSetupReady;
  } else {
    claim = PreparationClaim.readyToOfficiateOnThisPhone;
  }
  return PreparationAssessment(
    claim: claim,
    blockers: blockers,
    canEnterLiveMatch: identityComplete && operatingProfile,
  );
}
