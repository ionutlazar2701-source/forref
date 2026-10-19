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
}

final class ResearchLogEvent {
  const ResearchLogEvent({
    required this.kind,
    required this.scenarioId,
    required this.detail,
  });

  final ResearchLogKind kind;
  final String scenarioId;
  final String detail;
}

typedef ResearchLogSink = void Function(ResearchLogEvent event);
