import '../disciplinary_subject.dart';
import '../match_record.dart';
import '../record_kind.dart';
import '../semantics/v1_semantic_payload.dart';
import 'effective_goal_resolver.dart';

/// One Yellow whose current description and standing follow the generic resolver.
final class EffectiveYellow {
  const EffectiveYellow({
    required this.yellowRecordId,
    required this.subject,
    required this.accountingScope,
    required this.standing,
    required this.yellowSchemaVersion,
  });

  final String yellowRecordId;
  final DisciplinarySubjectRef subject;
  final DisciplinaryAccountingScope accountingScope;
  final bool standing;

  /// 1 for a stored participant Yellow. 2 for an additive subject payload.
  final int yellowSchemaVersion;
}

sealed class EffectiveYellowResolution {
  const EffectiveYellowResolution();
}

final class EffectiveYellowSet extends EffectiveYellowResolution {
  EffectiveYellowSet(List<EffectiveYellow> yellows)
      : yellows = List.unmodifiable(yellows);

  final List<EffectiveYellow> yellows;
}

final class EffectiveYellowConflicted extends EffectiveYellowResolution {
  const EffectiveYellowConflicted();
}

final class EffectiveYellowUnavailable extends EffectiveYellowResolution {
  const EffectiveYellowUnavailable();
}

/// Standing and historical Yellow effect. This is the goal resolver's
/// relationship walk, applied to Yellow descriptions. It does not create
/// SEND_OFF records.
EffectiveYellowResolution resolveEffectiveYellows({
  required Map<String, MatchRecord> recordsById,
}) {
  final yellowRecords = recordsById.values
      .where((record) => isYellowCardPayload(record.payload))
      .toList()
    ..sort((a, b) => a.recordId.compareTo(b.recordId));

  final subjectByYellow = <String, DisciplinarySubjectRef>{};
  final scopeByYellow = <String, DisciplinaryAccountingScope>{};
  for (final yellow in yellowRecords) {
    subjectByYellow[yellow.recordId] = subjectOfYellowCard(yellow.payload);
    scopeByYellow[yellow.recordId] = scopeOfYellowCard(yellow.payload);
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
      return const EffectiveYellowUnavailable();
    }
  }
  for (final supersession in supersessionRecords) {
    final targetId = legalSupersessionTargetOf(supersession);
    if (targetId == null || !recordsById.containsKey(targetId)) {
      return const EffectiveYellowUnavailable();
    }
  }

  final repairedSubjects = <String, Set<DisciplinarySubjectRef>>{};
  final repairedScopes = <String, Set<DisciplinaryAccountingScope>>{};
  for (final correction in correctionRecords) {
    final payload = correction.payload as CorrectionPayload;
    if (_yellowRepairFieldsConflict(payload)) {
      return const EffectiveYellowConflicted();
    }
    final repairedSubject = _repairedYellowSubject(payload);
    final repairedScope = _repairedYellowScope(payload);
    if (repairedSubject == null && repairedScope == null) continue;
    final walk = _walkToYellow(correctionTargetOf(correction)!, recordsById);
    if (walk.cycle) return const EffectiveYellowUnavailable();
    final yellowId = walk.yellowId;
    if (yellowId == null) continue;
    if (repairedSubject != null) {
      repairedSubjects.putIfAbsent(yellowId, () => {}).add(repairedSubject);
    }
    if (repairedScope != null) {
      repairedScopes.putIfAbsent(yellowId, () => {}).add(repairedScope);
    }
  }
  for (final entry in repairedSubjects.entries) {
    if (entry.value.length > 1) return const EffectiveYellowConflicted();
    subjectByYellow[entry.key] = entry.value.first;
  }
  for (final entry in repairedScopes.entries) {
    if (entry.value.length > 1) return const EffectiveYellowConflicted();
    scopeByYellow[entry.key] = entry.value.first;
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
      return const EffectiveYellowUnavailable();
    }
    if (effectiveness == RelationshipSupersessionEffectiveness.effective) {
      effectiveSupersessions.add(id);
    }
  }

  for (final supersessionId in effectiveSupersessions) {
    final targetId =
        legalSupersessionTargetOf(recordsById[supersessionId]!);
    final target = targetId == null ? null : recordsById[targetId];
    if (target != null &&
        target.recordKind == RecordKind.correction &&
        target.payload is CorrectionPayload &&
        _correctionReachesYellow(target, recordsById)) {
      return const EffectiveYellowUnavailable();
    }
  }

  final effective = <EffectiveYellow>[];
  for (final yellow in yellowRecords) {
    final voided = effectiveSupersessions.any(
      (supersessionId) =>
          legalSupersessionTargetOf(recordsById[supersessionId]!) ==
          yellow.recordId,
    );
    effective.add(
      EffectiveYellow(
        yellowRecordId: yellow.recordId,
        subject: subjectByYellow[yellow.recordId]!,
        accountingScope: scopeByYellow[yellow.recordId]!,
        standing: !voided,
        yellowSchemaVersion: yellowCardPayloadSchemaVersion(yellow.payload),
      ),
    );
  }
  effective.sort((a, b) => a.yellowRecordId.compareTo(b.yellowRecordId));
  return EffectiveYellowSet(effective);
}

bool _correctionReachesYellow(
  MatchRecord correction,
  Map<String, MatchRecord> recordsById,
) {
  if (_walkToYellow(correction.recordId, recordsById).yellowId != null) {
    return true;
  }
  final payload = correction.payload;
  return payload is CorrectionPayload &&
      (payload.repairedParticipantId != null ||
          payload.repairedAccountingScope != null);
}

DisciplinarySubjectRef? _repairedYellowSubject(CorrectionPayload payload) {
  final v1 = payload.repairedParticipantId == null
      ? null
      : ParticipantDisciplinarySubject(payload.repairedParticipantId!);
  final v2 = payload.repairedDisciplinarySubject;
  if (v1 != null && v2 != null && v1 != v2) return v1;
  return v2 ?? v1;
}

bool _yellowRepairFieldsConflict(CorrectionPayload payload) {
  final v1 = payload.repairedParticipantId == null
      ? null
      : ParticipantDisciplinarySubject(payload.repairedParticipantId!);
  final v2 = payload.repairedDisciplinarySubject;
  if (v1 != null && v2 != null && v1 != v2) return true;
  final v1Scope = payload.repairedAccountingScope;
  final v2Scope = payload.repairedDisciplinaryScope;
  return v1Scope != null && v2Scope != null && v1Scope != v2Scope;
}

DisciplinaryAccountingScope? _repairedYellowScope(CorrectionPayload payload) {
  if (_yellowRepairFieldsConflict(payload)) return null;
  return payload.repairedDisciplinaryScope ?? payload.repairedAccountingScope;
}

final class _YellowWalk {
  const _YellowWalk._({required this.cycle, this.yellowId});

  const _YellowWalk.cycle() : this._(cycle: true);

  const _YellowWalk.yellow(String yellowId)
      : this._(cycle: false, yellowId: yellowId);

  const _YellowWalk.notAYellow() : this._(cycle: false);

  final bool cycle;
  final String? yellowId;
}

_YellowWalk _walkToYellow(
  String recordId,
  Map<String, MatchRecord> recordsById,
) {
  final visiting = <String>{};
  var current = recordId;
  while (true) {
    if (visiting.contains(current)) return const _YellowWalk.cycle();
    visiting.add(current);
    final record = recordsById[current];
    if (record == null) return const _YellowWalk.notAYellow();
    if (isYellowCardPayload(record.payload)) {
      return _YellowWalk.yellow(current);
    }
    if (record.recordKind == RecordKind.correction) {
      final next = correctionTargetOf(record);
      if (next == null) return const _YellowWalk.notAYellow();
      current = next;
      continue;
    }
    return const _YellowWalk.notAYellow();
  }
}
