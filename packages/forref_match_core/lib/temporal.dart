/// Optional temporal context on a Match Record (references, not widget state).
final class TemporalContext {
  const TemporalContext({
    this.evidenceIds = const [],
    this.domainClockPolicyVersion,
    this.explicitUncertainty = false,
  });

  final List<String> evidenceIds;
  final String? domainClockPolicyVersion;

  /// The capture is bound to the domain clock, and an exact playing minute
  /// is not available. This is not a fabricated `00:00` or a wall-clock minute.
  final bool explicitUncertainty;
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
