import 'package:live_core_a/src/trial_task.dart';

/// Status of the 002D Recall instrument in this repository.
enum RecallInstrumentStatus {
  /// Instrument not present in repo; cautions trials cannot be formally scored.
  unavailable,
}

/// Whether a cautions trial may be scored under formal 002D protocol.
bool cautionsTrialIsFormal002dScorable({
  required TrialTask task,
  required RecallInstrumentStatus recallInstrument,
}) {
  if (task != TrialTask.cautions) {
    return false;
  }
  return recallInstrument != RecallInstrumentStatus.unavailable;
}
