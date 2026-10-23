import 'package:live_core_a/src/trial_task.dart';

/// Counterbalanced trial order entry (task + condition label only; no answers).
class OrderEntry {
  const OrderEntry({
    required this.task,
    required this.condition,
    required this.sequenceIndex,
  });

  final TrialTask task;
  final String condition;
  final int sequenceIndex;

  Map<String, Object?> toJson() => {
        'task': task.name,
        'condition': condition,
        'sequenceIndex': sequenceIndex,
      };

  static OrderEntry fromJson(Map<String, Object?> json) {
    return OrderEntry(
      task: TrialTask.values.byName(json['task']! as String),
      condition: json['condition']! as String,
      sequenceIndex: json['sequenceIndex']! as int,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OrderEntry &&
        other.task == task &&
        other.condition == condition &&
        other.sequenceIndex == sequenceIndex;
  }

  @override
  int get hashCode => Object.hash(task, condition, sequenceIndex);
}

/// Deterministic pseudo-random from [seed] (LCG); same seed => same sequence.
int _nextRand(int state) => (state * 1103515245 + 12345) & 0x7fffffff;

List<TrialTask> _allTasksInCanonicalOrder() => List<TrialTask>.from(
      TrialTask.values,
    );

/// Generates a counterbalanced task order without embedding expected answers.
List<OrderEntry> generateCounterbalancedOrder({required int seed}) {
  final tasks = _allTasksInCanonicalOrder();
  var state = seed == 0 ? 1 : seed;

  // Fisher–Yates shuffle with deterministic PRNG.
  for (var i = tasks.length - 1; i > 0; i--) {
    state = _nextRand(state);
    final j = state % (i + 1);
    final tmp = tasks[i];
    tasks[i] = tasks[j];
    tasks[j] = tmp;
  }

  return List<OrderEntry>.generate(tasks.length, (index) {
    state = _nextRand(state);
    final conditionCode = 'C${(state % 97).toString().padLeft(2, '0')}';
    return OrderEntry(
      task: tasks[index],
      condition: conditionCode,
      sequenceIndex: index,
    );
  });
}

/// Keys that must never appear in order export (would leak expected answers).
const Set<String> forbiddenOrderPayloadKeys = {
  'expectedScore',
  'expectedTime',
  'expectedPhase',
  'homeGoals',
  'awayGoals',
  'homeTeamId',
  'awayTeamId',
  'answer',
  'correctAnswer',
};

bool orderPayloadEmbedsExpectedAnswer(Map<String, Object?> json) {
  for (final key in json.keys) {
    if (forbiddenOrderPayloadKeys.contains(key)) {
      return true;
    }
  }
  if (json['entries'] is List) {
    for (final entry in json['entries']! as List) {
      if (entry is Map<String, Object?> &&
          orderPayloadEmbedsExpectedAnswer(entry)) {
        return true;
      }
    }
  }
  return false;
}

Map<String, Object?> exportOrderPlan({
  required int seed,
  required List<OrderEntry> order,
}) {
  return {
    'schema': 'live_core_a.order_plan.v1',
    'seed': seed,
    'entries': order.map((e) => e.toJson()).toList(),
  };
}
