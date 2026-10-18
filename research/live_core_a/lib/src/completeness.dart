import 'package:live_core_a/src/telemetry.dart';
import 'package:live_core_a/src/trial_task.dart';

enum CompletenessVerdict {
  complete,
  incompleteMissingEvents,
  incompleteMissingConfidence,
}

/// Minimum protocol events required for any trial to be considered complete.
const List<String> _baselineRequiredEvents = [
  TelemetryEvent.trialStarted,
  TelemetryEvent.stimulusPresented,
  TelemetryEvent.wristGlanceStarted,
  TelemetryEvent.answerOrActionRequested,
  TelemetryEvent.trialCompleted,
];

/// Additional events for one-contact destination tasks.
const List<String> _destinationRequiredEvents = [
  TelemetryEvent.targetTouch,
  TelemetryEvent.destinationOpened,
  TelemetryEvent.returnRequested,
  TelemetryEvent.liveReacquired,
];

/// Fact tasks require an answered fact before completion.
const List<String> _factRequiredEvents = [
  TelemetryEvent.factAnswered,
];

CompletenessVerdict computeCompletenessVerdict({
  required TrialTask task,
  required Map<String, DateTime> eventTimestamps,
}) {
  final required = <String>[
    ..._baselineRequiredEvents,
    if (trialTaskIsOneContactDestination(task)) ..._destinationRequiredEvents,
    if (_taskRequiresFactAnswer(task)) ..._factRequiredEvents,
  ];

  for (final name in required) {
    if (!eventTimestamps.containsKey(name)) {
      return CompletenessVerdict.incompleteMissingEvents;
    }
  }

  if (criticalTasks.contains(task) &&
      !eventTimestamps.containsKey(TelemetryEvent.confidenceRecorded)) {
    return CompletenessVerdict.incompleteMissingConfidence;
  }

  return CompletenessVerdict.complete;
}

bool _taskRequiresFactAnswer(TrialTask task) {
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
