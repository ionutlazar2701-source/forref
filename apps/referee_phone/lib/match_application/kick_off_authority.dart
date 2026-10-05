/// Result of the ordered Kick-off commits.
///
/// Kick-off is one physical intent and two durable records. These results
/// distinguish a completed start from a preserved but incomplete one.
sealed class KickOffAuthorityResult {
  const KickOffAuthorityResult();
}

/// Both `MATCH_STARTED` and `PERIOD_STARTED` are durably committed.
final class KickOffAuthorityCommitted extends KickOffAuthorityResult {
  const KickOffAuthorityCommitted({
    required this.matchStartedRecordId,
    required this.periodStartedRecordId,
  });

  final String matchStartedRecordId;
  final String periodStartedRecordId;
}

/// `MATCH_STARTED` is durable. `PERIOD_STARTED` is not.
final class KickOffMatchStartedIncomplete extends KickOffAuthorityResult {
  const KickOffMatchStartedIncomplete({
    required this.matchStartedRecordId,
    required this.periodFailureReason,
  });

  final String matchStartedRecordId;
  final String periodFailureReason;
}

/// Both records were already committed. No additional record was written.
final class KickOffAlreadyStarted extends KickOffAuthorityResult {
  const KickOffAlreadyStarted();
}

/// `MATCH_STARTED` was not committed. Visible state stays pre-kick-off.
final class KickOffAuthorityRejected extends KickOffAuthorityResult {
  const KickOffAuthorityRejected({required this.reason});

  final String reason;
}
