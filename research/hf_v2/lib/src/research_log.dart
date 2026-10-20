enum ResearchLogKind {
  scenarioStarted,
  surfaceEntered,
  teamContextApplied,
  teamManuallyChanged,
  subjectSelected,
  subjectInvalidated,
  officialSelected,
  priorCautionShown,
  outSelected,
  inSelected,
  pairReviewed,
  finalActionArmed,
  finalActionActivated,
  simulatedCommitStarted,
  simulatedCommitOutcome,
  interruption,
  resume,
  scope,
  userCorrection,
  scenarioCompleted,
  scenarioAbandoned,
  profileSelected,
  activeDeviceChanged,
  pointerDown,
  pointerUp,
  pointerCancelled,
  focusLost,
  frozenCommand,
  researchRecordAppended,
  layoutChanged,
  inputRejected,
}

final class ResearchLogEvent {
  const ResearchLogEvent({
    required this.kind,
    required this.scenarioId,
    required this.detail,
    required this.sequence,
  });

  final ResearchLogKind kind;
  final String scenarioId;
  final String detail;

  /// Monotonic research sequence. Not a wall-clock timestamp.
  final int sequence;
}

typedef ResearchLogSink = void Function(ResearchLogEvent event);
