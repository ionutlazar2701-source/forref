import '../match_participant.dart';
import '../match_record.dart';
import '../match_team.dart';
import '../record_kind.dart';
import '../semantics/v1_semantic_payload.dart';
import 'effective_goal_resolver.dart';

/// One completed substitution after correction and supersession.
final class EffectiveSubstitution {
  const EffectiveSubstitution({
    required this.substitutionRecordId,
    required this.outgoingParticipantId,
    required this.incomingParticipantId,
    required this.teamId,
    required this.legallyEffective,
    required this.originDeviceId,
    required this.originSequence,
  });

  final String substitutionRecordId;
  final MatchParticipantId outgoingParticipantId;
  final MatchParticipantId incomingParticipantId;
  final MatchTeamId teamId;
  final bool legallyEffective;
  final String originDeviceId;
  final int originSequence;
}

sealed class EffectiveSubstitutionResolution {
  const EffectiveSubstitutionResolution();
}

final class EffectiveSubstitutionSet extends EffectiveSubstitutionResolution {
  EffectiveSubstitutionSet(List<EffectiveSubstitution> substitutions)
      : substitutions = List.unmodifiable(substitutions);

  final List<EffectiveSubstitution> substitutions;
}

final class EffectiveSubstitutionConflicted
    extends EffectiveSubstitutionResolution {
  const EffectiveSubstitutionConflicted();
}

final class EffectiveSubstitutionUnavailable
    extends EffectiveSubstitutionResolution {
  const EffectiveSubstitutionUnavailable();
}

/// Completed-substitution effect. Identity is not minted here.
EffectiveSubstitutionResolution resolveEffectiveSubstitutions({
  required Map<String, MatchRecord> recordsById,
}) {
  final substitutionRecords = recordsById.values
      .where((record) => record.payload is SubstitutionPayload)
      .toList()
    ..sort((a, b) => a.recordId.compareTo(b.recordId));

  final outgoingById = <String, MatchParticipantId>{};
  final incomingById = <String, MatchParticipantId>{};
  final teamById = <String, MatchTeamId>{};
  for (final substitution in substitutionRecords) {
    final payload = substitution.payload as SubstitutionPayload;
    outgoingById[substitution.recordId] = payload.outgoingParticipantId;
    incomingById[substitution.recordId] = payload.incomingParticipantId;
    teamById[substitution.recordId] = payload.teamId;
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
    final targetId = correctionTargetOf(correction);
    if (targetId == null || !recordsById.containsKey(targetId)) {
      return const EffectiveSubstitutionUnavailable();
    }
  }
  for (final supersession in supersessionRecords) {
    final targetId = legalSupersessionTargetOf(supersession);
    if (targetId == null || !recordsById.containsKey(targetId)) {
      return const EffectiveSubstitutionUnavailable();
    }
  }

  final repairedOutgoing = <String, Set<MatchParticipantId>>{};
  final repairedIncoming = <String, Set<MatchParticipantId>>{};
  final repairedTeams = <String, Set<MatchTeamId>>{};
  for (final correction in correctionRecords) {
    final payload = correction.payload as CorrectionPayload;
    final walk = _walkToSubstitution(
      correctionTargetOf(correction)!,
      recordsById,
    );
    if (walk.cycle) return const EffectiveSubstitutionUnavailable();
    final substitutionId = walk.substitutionId;
    if (substitutionId == null) continue;
    if (payload.repairedOutgoingParticipantId != null) {
      repairedOutgoing
          .putIfAbsent(substitutionId, () => {})
          .add(payload.repairedOutgoingParticipantId!);
    }
    if (payload.repairedIncomingParticipantId != null) {
      repairedIncoming
          .putIfAbsent(substitutionId, () => {})
          .add(payload.repairedIncomingParticipantId!);
    }
    if (payload.repairedSubstitutionTeamId != null) {
      repairedTeams
          .putIfAbsent(substitutionId, () => {})
          .add(payload.repairedSubstitutionTeamId!);
    }
  }
  for (final entry in repairedOutgoing.entries) {
    if (entry.value.length > 1) return const EffectiveSubstitutionConflicted();
    outgoingById[entry.key] = entry.value.first;
  }
  for (final entry in repairedIncoming.entries) {
    if (entry.value.length > 1) return const EffectiveSubstitutionConflicted();
    incomingById[entry.key] = entry.value.first;
  }
  for (final entry in repairedTeams.entries) {
    if (entry.value.length > 1) return const EffectiveSubstitutionConflicted();
    teamById[entry.key] = entry.value.first;
  }
  for (final substitution in substitutionRecords) {
    if (outgoingById[substitution.recordId] ==
        incomingById[substitution.recordId]) {
      return const EffectiveSubstitutionConflicted();
    }
  }

  final supersessionIds = supersessionRecords.map((r) => r.recordId).toList();
  final effectiveSupersessions = <String>{};
  for (final id in supersessionIds) {
    final effectiveness = relationshipSupersessionEffectiveness(
      id,
      recordsById: recordsById,
      supersessionIds: supersessionIds,
      memo: {},
      visiting: {},
    );
    if (effectiveness == RelationshipSupersessionEffectiveness.cycle) {
      return const EffectiveSubstitutionUnavailable();
    }
    if (effectiveness == RelationshipSupersessionEffectiveness.effective) {
      effectiveSupersessions.add(id);
    }
  }
  for (final supersessionId in effectiveSupersessions) {
    final targetId = legalSupersessionTargetOf(recordsById[supersessionId]!);
    final target = targetId == null ? null : recordsById[targetId];
    if (target != null &&
        target.recordKind == RecordKind.correction &&
        target.payload is CorrectionPayload &&
        _walkToSubstitution(target.recordId, recordsById).substitutionId !=
            null) {
      return const EffectiveSubstitutionUnavailable();
    }
  }

  final effective = <EffectiveSubstitution>[];
  for (final substitution in substitutionRecords) {
    final voided = effectiveSupersessions.any(
      (supersessionId) =>
          legalSupersessionTargetOf(recordsById[supersessionId]!) ==
          substitution.recordId,
    );
    effective.add(
      EffectiveSubstitution(
        substitutionRecordId: substitution.recordId,
        outgoingParticipantId: outgoingById[substitution.recordId]!,
        incomingParticipantId: incomingById[substitution.recordId]!,
        teamId: teamById[substitution.recordId]!,
        legallyEffective: !voided,
        originDeviceId: substitution.originDeviceId,
        originSequence: substitution.originSequence,
      ),
    );
  }
  effective.sort(
    (a, b) => a.substitutionRecordId.compareTo(b.substitutionRecordId),
  );
  return EffectiveSubstitutionSet(effective);
}

sealed class ParticipantStatusProjection {
  const ParticipantStatusProjection();
}

/// Status proved by completed substitutions. Absent ids are not asserted.
final class ProjectedParticipantStatus extends ParticipantStatusProjection {
  ProjectedParticipantStatus(Map<MatchParticipantId, ParticipantSituation> status)
      : statusByParticipant = Map.unmodifiable(status);

  final Map<MatchParticipantId, ParticipantSituation> statusByParticipant;
}

final class ParticipantStatusUnavailable extends ParticipantStatusProjection {
  const ParticipantStatusUnavailable();
}

final class ParticipantStatusConflicted extends ParticipantStatusProjection {
  const ParticipantStatusConflicted();
}

/// Latest completed substitution wins inside one origin.
///
/// OUT becomes [ParticipantSituation.substituted]. IN becomes
/// [ParticipantSituation.onField]. A later entry of a substituted
/// participant restores on-field without a new id.
ParticipantStatusProjection projectParticipantStatus({
  required Map<String, MatchRecord> recordsById,
}) {
  final resolved = resolveEffectiveSubstitutions(recordsById: recordsById);
  if (resolved is EffectiveSubstitutionUnavailable) {
    return const ParticipantStatusUnavailable();
  }
  if (resolved is EffectiveSubstitutionConflicted) {
    return const ParticipantStatusConflicted();
  }
  final substitutions = (resolved as EffectiveSubstitutionSet)
      .substitutions
      .where((item) => item.legallyEffective)
      .toList();
  final devices = substitutions.map((item) => item.originDeviceId).toSet();
  if (devices.length > 1) return const ParticipantStatusUnavailable();
  final seenSequences = <int>{};
  for (final substitution in substitutions) {
    if (!seenSequences.add(substitution.originSequence)) {
      return const ParticipantStatusUnavailable();
    }
  }
  substitutions.sort((a, b) {
    final bySequence = a.originSequence.compareTo(b.originSequence);
    if (bySequence != 0) return bySequence;
    return a.substitutionRecordId.compareTo(b.substitutionRecordId);
  });
  final status = <MatchParticipantId, ParticipantSituation>{};
  for (final substitution in substitutions) {
    status[substitution.outgoingParticipantId] =
        ParticipantSituation.substituted;
    status[substitution.incomingParticipantId] = ParticipantSituation.onField;
  }
  return ProjectedParticipantStatus(status);
}

final class _SubstitutionWalk {
  const _SubstitutionWalk._({required this.cycle, this.substitutionId});

  const _SubstitutionWalk.cycle() : this._(cycle: true);

  const _SubstitutionWalk.substitution(String substitutionId)
      : this._(cycle: false, substitutionId: substitutionId);

  const _SubstitutionWalk.notASubstitution() : this._(cycle: false);

  final bool cycle;
  final String? substitutionId;
}

_SubstitutionWalk _walkToSubstitution(
  String recordId,
  Map<String, MatchRecord> recordsById,
) {
  final visiting = <String>{};
  var current = recordId;
  while (true) {
    if (visiting.contains(current)) return const _SubstitutionWalk.cycle();
    visiting.add(current);
    final record = recordsById[current];
    if (record == null) return const _SubstitutionWalk.notASubstitution();
    if (record.payload is SubstitutionPayload) {
      return _SubstitutionWalk.substitution(current);
    }
    if (record.recordKind == RecordKind.correction) {
      final next = correctionTargetOf(record);
      if (next == null) return const _SubstitutionWalk.notASubstitution();
      current = next;
      continue;
    }
    return const _SubstitutionWalk.notASubstitution();
  }
}
