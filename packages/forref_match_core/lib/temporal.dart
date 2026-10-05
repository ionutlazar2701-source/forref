/// Optional temporal context on a Match Record (references, not widget state).
final class TemporalContext {
  const TemporalContext({
    this.evidenceIds = const [],
    this.domainClockPolicyVersion,
  });

  final List<String> evidenceIds;
  final String? domainClockPolicyVersion;
}

/// Evidence artifact resolved through [TemporalEvidencePort].
///
/// [capturedAt] is chronology only. Match elapsed comes from monotonic
/// readings inside one [continuityDomainId]. A reading is exact when
/// [monotonicUpperBound] is absent. An upper bound makes the reading an
/// interval. [certified] is platform certification, which phone evidence
/// in this window does not claim.
final class TemporalEvidence {
  const TemporalEvidence({
    required this.evidenceId,
    required this.capturedAt,
    this.continuityDomainId,
    this.monotonicElapsed,
    this.monotonicUpperBound,
    this.certified = false,
  });

  final String evidenceId;
  final DateTime capturedAt;
  final String? continuityDomainId;

  /// Monotonic offset from the continuity-domain epoch.
  ///
  /// Lower bound when [monotonicUpperBound] is also set.
  final Duration? monotonicElapsed;

  /// Inclusive upper bound. Present only for an interval reading.
  final Duration? monotonicUpperBound;

  final bool certified;

  bool get isInterval => monotonicUpperBound != null;
}
