import 'package:live_core_a/src/completeness.dart';
import 'package:live_core_a/src/recall_instrument.dart';
import 'package:live_core_a/src/telemetry.dart';
import 'package:live_core_a/src/trial_task.dart';

/// Single Central Instrument A trial observation (instrumentation only).
class TrialRecord {
  TrialRecord({
    required this.task,
    required this.condition,
    Map<String, DateTime>? eventTimestamps,
    this.firstAttemptSuccess,
    this.wrongDestination = false,
    this.retries = 0,
    this.confidence,
    RecallInstrumentStatus? recallInstrument,
  })  : eventTimestamps = Map<String, DateTime>.from(eventTimestamps ?? {}),
        recallInstrument = task == TrialTask.cautions
            ? RecallInstrumentStatus.unavailable
            : recallInstrument;

  final TrialTask task;
  final String condition;
  final Map<String, DateTime> eventTimestamps;
  bool? firstAttemptSuccess;
  bool wrongDestination;
  int retries;
  double? confidence;
  final RecallInstrumentStatus? recallInstrument;

  CompletenessVerdict get completenessVerdict => computeCompletenessVerdict(
        task: task,
        eventTimestamps: eventTimestamps,
      );

  bool get formal002dScorable => cautionsTrialIsFormal002dScorable(
        task: task,
        recallInstrument:
            recallInstrument ?? RecallInstrumentStatus.unavailable,
      );

  void recordEvent(String eventName, DateTime at) {
    if (!TelemetryEvent.all.contains(eventName)) {
      throw ArgumentError.value(eventName, 'eventName', 'unknown telemetry');
    }
    eventTimestamps[eventName] = at;
  }

  void recordConfidence(double value) {
    confidence = value;
    recordEvent(TelemetryEvent.confidenceRecorded, DateTime.now().toUtc());
  }

  Map<String, Object?> toJson() => {
        'task': task.name,
        'condition': condition,
        'eventTimestamps': eventTimestamps.map(
          (k, v) => MapEntry(k, v.toUtc().toIso8601String()),
        ),
        'firstAttemptSuccess': firstAttemptSuccess,
        'wrongDestination': wrongDestination,
        'retries': retries,
        'confidence': confidence,
        'completenessVerdict': completenessVerdict.name,
        if (task == TrialTask.cautions)
          'recallInstrument': RecallInstrumentStatus.unavailable.name,
        'formal002dScorable': formal002dScorable,
      };

  static TrialRecord fromJson(Map<String, Object?> json) {
    final task = TrialTask.values.byName(json['task']! as String);
    final timestampsRaw = json['eventTimestamps']! as Map<String, Object?>;
    final timestamps = timestampsRaw.map(
      (k, v) => MapEntry(k, DateTime.parse(v! as String)),
    );
    final record = TrialRecord(
      task: task,
      condition: json['condition']! as String,
      eventTimestamps: timestamps,
      firstAttemptSuccess: json['firstAttemptSuccess'] as bool?,
      wrongDestination: json['wrongDestination'] as bool? ?? false,
      retries: json['retries'] as int? ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
    return record;
  }
}
