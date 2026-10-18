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
      .toList();

  final supersessionRecords = recordsById.values
      .where((record) => record.recordKind == RecordKind.legalSupersession)
      .toList();

  for (final correction in correctionRecords) {
    final targetId = _correctionTarget(correction);
    if (targetId == null || !recordsById.containsKey(targetId)) {
      return const EffectiveGoalUnavailable();
    }
  }
  for (final supersession in supersessionRecords) {
    final targetId = _supersessionTarget(supersession);
    if (targetId == null || !recordsById.containsKey(targetId)) {
      return const EffectiveGoalUnavailable();
    }
  }

  final repairedTeamsByGoal = <String, Set<MatchTeamId>>{};
  for (final correction in correctionRecords) {
    final repaired =
        (correction.payload as CorrectionPayload).repairedScoringTeamId;
    if (repaired == null) continue;
    final goalId = _ultimateGoalIdForRecord(
      _correctionTarget(correction)!,
      recordsById,
    );
    if (goalId == null) continue;
    repairedTeamsByGoal.putIfAbsent(goalId, () => {}).add(repaired);
  }
  for (final entry in repairedTeamsByGoal.entries) {
    if (entry.value.length > 1) {
      return const EffectiveGoalConflicted();
    }
    scoringTeamByGoal[entry.key] = entry.value.first;
  }

  final supersessionIds = supersessionRecords.map((r) => r.recordId).toList();
  final effectiveSupersessions = <String>{};
  for (final id in supersessionIds) {
    final effectiveness = _supersessionEffectiveness(
      id,
      recordsById: recordsById,
      supersessionIds: supersessionIds,
      memo: {},
      visiting: {},
    );
    if (effectiveness == _SupersessionEffectiveness.cycle) {
      return const EffectiveGoalUnavailable();
    }
    if (effectiveness == _SupersessionEffectiveness.effective) {
      effectiveSupersessions.add(id);
    }
  }

  final effective = <EffectiveGoal>[];
  for (final goal in goalRecords) {
    final voided = effectiveSupersessions.any(
      (supersessionId) =>
          _supersessionTarget(recordsById[supersessionId]!) == goal.recordId,
    );
    if (voided) continue;
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

enum _SupersessionEffectiveness { effective, voided, cycle }

/// A supersession is effective only when no effective supersession targets it.
_SupersessionEffectiveness _supersessionEffectiveness(
  String supersessionId, {
  required Map<String, MatchRecord> recordsById,
  required List<String> supersessionIds,
  required Map<String, _SupersessionEffectiveness> memo,
  required Set<String> visiting,
}) {
  final cached = memo[supersessionId];
  if (cached != null) return cached;
  if (visiting.contains(supersessionId)) {
    return _SupersessionEffectiveness.cycle;
  }
  visiting.add(supersessionId);

  for (final candidateId in supersessionIds) {
    if (candidateId == supersessionId) continue;
    final candidate = recordsById[candidateId]!;
    final targetId = _supersessionTarget(candidate);
    if (targetId != supersessionId) continue;
    final candidateEffect = _supersessionEffectiveness(
      candidateId,
      recordsById: recordsById,
      supersessionIds: supersessionIds,
      memo: memo,
      visiting: visiting,
    );
    if (candidateEffect == _SupersessionEffectiveness.cycle) {
      visiting.remove(supersessionId);
      return _SupersessionEffectiveness.cycle;
    }
    if (candidateEffect == _SupersessionEffectiveness.effective) {
      visiting.remove(supersessionId);
      memo[supersessionId] = _SupersessionEffectiveness.voided;
      return _SupersessionEffectiveness.voided;
    }
  }

  visiting.remove(supersessionId);
  memo[supersessionId] = _SupersessionEffectiveness.effective;
  return _SupersessionEffectiveness.effective;
}

String? _ultimateGoalIdForRecord(
  String recordId,
  Map<String, MatchRecord> recordsById,
) {
  final visiting = <String>{};
  var current = recordId;
  while (true) {
    if (visiting.contains(current)) return null;
    visiting.add(current);
    final record = recordsById[current];
    if (record == null) return null;
    if (record.payload is GoalPayload) return current;
    if (record.recordKind == RecordKind.correction) {
      final next = _correctionTarget(record);
      if (next == null) return null;
      current = next;
      continue;
    }
    return null;
  }
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
