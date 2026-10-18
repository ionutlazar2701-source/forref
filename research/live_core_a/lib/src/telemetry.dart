/// Canonical telemetry event names for Central Instrument A trials.
abstract final class TelemetryEvent {
  static const trialStarted = 'trial_started';
  static const stimulusPresented = 'stimulus_presented';
  static const wristGlanceStarted = 'wrist_glance_started';
  static const answerOrActionRequested = 'answer_or_action_requested';
  static const targetTouch = 'target_touch';
  static const destinationOpened = 'destination_opened';
  static const factAnswered = 'fact_answered';
  static const confidenceRecorded = 'confidence_recorded';
  static const returnRequested = 'return_requested';
  static const liveReacquired = 'live_reacquired';
  static const trialCompleted = 'trial_completed';

  static const all = <String>[
    trialStarted,
    stimulusPresented,
    wristGlanceStarted,
    answerOrActionRequested,
    targetTouch,
    destinationOpened,
    factAnswered,
    confidenceRecorded,
    returnRequested,
    liveReacquired,
    trialCompleted,
  ];
}
