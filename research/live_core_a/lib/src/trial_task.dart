/// Trial tasks for Central Instrument A protocol completeness measurement.
enum TrialTask {
  timeOnly,
  phaseOnly,
  scoreOnly,
  timeAndScore,
  capture,
  cautions,
  interruption,
  boundaryTime,
  poorAngle,
  movementWet,
}

/// Tasks where [TelemetryEvent.confidenceRecorded] is required for completeness.
const Set<TrialTask> criticalTasks = {
  TrialTask.scoreOnly,
  TrialTask.timeAndScore,
  TrialTask.capture,
  TrialTask.cautions,
};

/// Zero-navigation fact tasks (TIME+PHASE, SCORE dimensions).
bool trialTaskIsZeroNavigationFact(TrialTask task) {
  switch (task) {
    case TrialTask.timeOnly:
    case TrialTask.phaseOnly:
    case TrialTask.scoreOnly:
    case TrialTask.timeAndScore:
    case TrialTask.boundaryTime:
      return true;
    case TrialTask.capture:
    case TrialTask.cautions:
    case TrialTask.interruption:
    case TrialTask.poorAngle:
    case TrialTask.movementWet:
      return false;
  }
}

/// One-contact destination tasks (CAPTURE, CAUTIONS).
bool trialTaskIsOneContactDestination(TrialTask task) {
  return task == TrialTask.capture || task == TrialTask.cautions;
}
