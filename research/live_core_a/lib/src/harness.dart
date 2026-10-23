import 'package:live_core_a/src/order_generator.dart';
import 'package:live_core_a/src/session_export.dart';
import 'package:live_core_a/src/telemetry.dart';
import 'package:live_core_a/src/trial_record.dart';

/// Standalone harness entry point for planning Instrument A trial runs.
class CentralInstrumentAHarness {
  CentralInstrumentAHarness({required this.orderSeed});

  final int orderSeed;

  List<OrderEntry> planTrials() =>
      generateCounterbalancedOrder(seed: orderSeed);

  ResearchSession newSession({required String sessionId}) {
    return ResearchSession(
      sessionId: sessionId,
      orderSeed: orderSeed,
      participantOpaqueIds: const [],
      trials: const [],
    );
  }

  TrialRecord beginTrial({
    required OrderEntry entry,
    DateTime? at,
  }) {
    final now = (at ?? DateTime.now()).toUtc();
    final record = TrialRecord(
      task: entry.task,
      condition: entry.condition,
    );
    record.recordEvent(TelemetryEvent.trialStarted, now);
    return record;
  }
}

/// Helper to stamp the standard stimulus flow (caller supplies wall times).
void stampStandardStimulusFlow(
  TrialRecord record, {
  required DateTime stimulusAt,
  required DateTime wristGlanceAt,
  required DateTime answerRequestedAt,
}) {
  record.recordEvent(TelemetryEvent.stimulusPresented, stimulusAt);
  record.recordEvent(TelemetryEvent.wristGlanceStarted, wristGlanceAt);
  record.recordEvent(TelemetryEvent.answerOrActionRequested, answerRequestedAt);
}

void completeTrial(TrialRecord record, {DateTime? at}) {
  record.recordEvent(
    TelemetryEvent.trialCompleted,
    (at ?? DateTime.now()).toUtc(),
  );
}
