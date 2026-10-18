import '../match_record.dart';
import '../match_team.dart';
import '../record_kind.dart';
import '../relationships.dart';
import '../semantics/v1_semantic_payload.dart';

/// One Goal that currently counts toward score after corrections and supersession.
final class EffectiveGoal {
  const EffectiveGoal({
    required this.goalRecordId,
    required this.scoringTeamId,
  });

  final String goalRecordId;
  final MatchTeamId scoringTeamId;
}

sealed class EffectiveGoalResolution {
  const EffectiveGoalResolution();
}

final class EffectiveGoalSet extends EffectiveGoalResolution {
  EffectiveGoalSet(List<EffectiveGoal> goals)
      : goals = List.unmodifiable(goals);

  final List<EffectiveGoal> goals;
}

final class EffectiveGoalConflicted extends EffectiveGoalResolution {
  const EffectiveGoalConflicted();
}

final class EffectiveGoalUnavailable extends EffectiveGoalResolution {
  const EffectiveGoalUnavailable();
}

/// Deterministic effective Goal set. Order of input records must not matter.
EffectiveGoalResolution resolveEffectiveGoals({
  required Map<String, MatchRecord> recordsById,
}) {
  final goalRecords = recordsById.values
      .where((record) => record.payload is GoalPayload)
      .toList()
    ..sort((a, b) => a.recordId.compareTo(b.recordId));

  if (_hasSupersessionCycle(recordsById)) {
    return const EffectiveGoalUnavailable();
  }

  final scoringTeamByGoal = <String, MatchTeamId>{};
  for (final goal in goalRecords) {
    final payload = goal.payload as GoalPayload;
    scoringTeamByGoal[goal.recordId] = payload.scoringTeamId;
  }

  final correctionRecords = recordsById.values
      .where(
        (record) =>
            record.recordKind == RecordKind.correction &&
            record.payload is CorrectionPayload,
      )
      .toList()
    ..sort((a, b) => a.recordId.compareTo(b.recordId));

  final correctionsByGoalTarget = <String, List<MatchRecord>>{};
  for (final correction in correctionRecords) {
    final targetId = _correctionTarget(correction);
    if (targetId == null) {
      return const EffectiveGoalUnavailable();
    }
    if (!scoringTeamByGoal.containsKey(targetId)) continue;
    correctionsByGoalTarget.putIfAbsent(targetId, () => []).add(correction);
  }
  for (final corrections in correctionsByGoalTarget.values) {
    final teams = corrections
        .map(
          (candidate) =>
              (candidate.payload as CorrectionPayload).repairedScoringTeamId,
        )
        .whereType<MatchTeamId>()
        .toSet();
    if (teams.length > 1) {
      return const EffectiveGoalConflicted();
    }
  }
  for (final correction in correctionRecords) {
    final targetId = _correctionTarget(correction);
    if (targetId == null || !scoringTeamByGoal.containsKey(targetId)) {
      continue;
    }
    final repaired =
        (correction.payload as CorrectionPayload).repairedScoringTeamId;
    if (repaired != null) {
      scoringTeamByGoal[targetId] = repaired;
    }
  }

  final goalActive = <String, bool>{
    for (final goal in goalRecords) goal.recordId: true,
  };

  final supersessionRecords = recordsById.values
      .where((record) => record.recordKind == RecordKind.legalSupersession)
      .toList()
    ..sort((a, b) => a.recordId.compareTo(b.recordId));

  for (final supersession in supersessionRecords) {
    final targetId = _supersessionTarget(supersession);
    if (targetId == null) {
      return const EffectiveGoalUnavailable();
    }
    final target = recordsById[targetId];
    if (target == null) {
      return const EffectiveGoalUnavailable();
    }
    if (target.payload is GoalPayload) {
      goalActive[targetId] = false;
      continue;
    }
    if (target.recordKind == RecordKind.legalSupersession) {
      final restoredGoalId = _goalVoidedBySupersession(recordsById, target);
      if (restoredGoalId != null) {
        goalActive[restoredGoalId] = true;
      }
    }
  }

  final effective = <EffectiveGoal>[];
  for (final goal in goalRecords) {
    if (goalActive[goal.recordId] != true) continue;
    effective.add(
      EffectiveGoal(
        goalRecordId: goal.recordId,
        scoringTeamId: scoringTeamByGoal[goal.recordId]!,
      ),
    );
  }
  effective.sort((a, b) => a.goalRecordId.compareTo(b.goalRecordId));
  return EffectiveGoalSet(effective);
}

String? _correctionTarget(MatchRecord record) {
  for (final link in record.relationships) {
    if (link is CorrectionTarget) return link.targetRecordId;
  }
  return null;
}

String? _supersessionTarget(MatchRecord record) {
  for (final link in record.relationships) {
    if (link is LegalSupersessionTarget) return link.targetRecordId;
  }
  return null;
}

String? _goalVoidedBySupersession(
  Map<String, MatchRecord> recordsById,
  MatchRecord supersession,
) {
  final targetId = _supersessionTarget(supersession);
  if (targetId == null) return null;
  final target = recordsById[targetId];
  if (target?.payload is GoalPayload) return targetId;
  return null;
}

bool _hasSupersessionCycle(Map<String, MatchRecord> recordsById) {
  final graph = <String, String>{};
  for (final record in recordsById.values) {
    if (record.recordKind != RecordKind.legalSupersession) continue;
    final target = _supersessionTarget(record);
    if (target == null) continue;
    graph[record.recordId] = target;
  }

  final visiting = <String>{};
  final visited = <String>{};

  bool dfs(String node) {
    if (visiting.contains(node)) return true;
    if (visited.contains(node)) return false;
    visiting.add(node);
    final next = graph[node];
    if (next != null && dfs(next)) return true;
    visiting.remove(node);
    visited.add(node);
    return false;
  }

  for (final node in graph.keys) {
    if (dfs(node)) return true;
  }
  return false;
}
