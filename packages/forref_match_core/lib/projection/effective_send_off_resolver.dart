import '../disciplinary_subject.dart';
import '../match_record.dart';
import '../record_kind.dart';
import '../relationships.dart';
import '../semantics/v1_semantic_payload.dart';
import 'effective_goal_resolver.dart';
import 'effective_yellow_resolver.dart';

/// Whether a SEND_OFF's typed Yellow dependencies are proven.
enum SendOffDependencyStatus {
  ready,
  unavailable,
  conflicted,
}

/// One explicit SEND_OFF after the generic correction and supersession walk.
final class EffectiveSendOff {
  const EffectiveSendOff({
    required this.sendOffRecordId,
    required this.subject,
    required this.scope,
    required this.pathway,
    required this.legallyEffective,
    required this.dependencyStatus,
  });

  final String sendOffRecordId;
  final DisciplinarySubjectRef subject;
  final DisciplinaryAccountingScope scope;
  final SendOffPathway pathway;

  /// False when an effective supersession targets this SEND_OFF.
  ///
  /// The Match Record remains. A later Yellow supersession does not clear this.
  final bool legallyEffective;
  final SendOffDependencyStatus dependencyStatus;
}

sealed class EffectiveSendOffResolution {
  const EffectiveSendOffResolution();
}

final class EffectiveSendOffSet extends EffectiveSendOffResolution {
  EffectiveSendOffSet(List<EffectiveSendOff> sendOffs)
      : sendOffs = List.unmodifiable(sendOffs);

  final List<EffectiveSendOff> sendOffs;
}

final class EffectiveSendOffConflicted extends EffectiveSendOffResolution {
  const EffectiveSendOffConflicted();
}

final class EffectiveSendOffUnavailable extends EffectiveSendOffResolution {
  const EffectiveSendOffUnavailable();
}

/// Explicit SEND_OFF effect. This walk does not create records from Yellow counts.
EffectiveSendOffResolution resolveEffectiveSendOffs({
  required Map<String, MatchRecord> recordsById,
}) {
  final sendOffRecords = recordsById.values
      .where((record) => record.payload is SendOffPayload)
      .toList()
    ..sort((a, b) => a.recordId.compareTo(b.recordId));

  final subjectBySendOff = <String, DisciplinarySubjectRef>{};
  final scopeBySendOff = <String, DisciplinaryAccountingScope>{};
  for (final sendOff in sendOffRecords) {
    final payload = sendOff.payload as SendOffPayload;
    subjectBySendOff[sendOff.recordId] = payload.disciplinarySubject;
    scopeBySendOff[sendOff.recordId] = payload.disciplinaryScope;
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
      return const EffectiveSendOffUnavailable();
    }
  }
  for (final supersession in supersessionRecords) {
    final targetId = legalSupersessionTargetOf(supersession);
    if (targetId == null || !recordsById.containsKey(targetId)) {
      return const EffectiveSendOffUnavailable();
    }
  }

  final repairedSubjects = <String, Set<DisciplinarySubjectRef>>{};
  final repairedScopes = <String, Set<DisciplinaryAccountingScope>>{};
  for (final correction in correctionRecords) {
    final payload = correction.payload as CorrectionPayload;
    if (_yellowRepairFieldsConflict(payload)) {
      return const EffectiveSendOffConflicted();
    }
    final walk = _walkToSendOff(correctionTargetOf(correction)!, recordsById);
    if (walk.cycle) return const EffectiveSendOffUnavailable();
    final sendOffId = walk.sendOffId;
    if (sendOffId == null) continue;
    final subject = payload.repairedDisciplinarySubject;
    final scope =
        payload.repairedDisciplinaryScope ?? payload.repairedAccountingScope;
    if (subject != null) {
      repairedSubjects.putIfAbsent(sendOffId, () => {}).add(subject);
    }
    if (scope != null) {
      repairedScopes.putIfAbsent(sendOffId, () => {}).add(scope);
    }
  }
  for (final entry in repairedSubjects.entries) {
    if (entry.value.length > 1) return const EffectiveSendOffConflicted();
    subjectBySendOff[entry.key] = entry.value.first;
  }
  for (final entry in repairedScopes.entries) {
    if (entry.value.length > 1) return const EffectiveSendOffConflicted();
    scopeBySendOff[entry.key] = entry.value.first;
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
      return const EffectiveSendOffUnavailable();
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
        _walkToSendOff(target.recordId, recordsById).sendOffId != null) {
      return const EffectiveSendOffUnavailable();
    }
  }

  final yellowResolution = resolveEffectiveYellows(recordsById: recordsById);
  final effective = <EffectiveSendOff>[];
  for (final sendOff in sendOffRecords) {
    final voided = effectiveSupersessions.any(
      (supersessionId) =>
          legalSupersessionTargetOf(recordsById[supersessionId]!) ==
          sendOff.recordId,
    );
    effective.add(
      EffectiveSendOff(
        sendOffRecordId: sendOff.recordId,
        subject: subjectBySendOff[sendOff.recordId]!,
        scope: scopeBySendOff[sendOff.recordId]!,
        pathway: (sendOff.payload as SendOffPayload).pathway,
        legallyEffective: !voided,
        dependencyStatus: _dependencyStatus(
          sendOff: sendOff,
          subject: subjectBySendOff[sendOff.recordId]!,
          scope: scopeBySendOff[sendOff.recordId]!,
          recordsById: recordsById,
          yellowResolution: yellowResolution,
        ),
      ),
    );
  }
  effective.sort((a, b) => a.sendOffRecordId.compareTo(b.sendOffRecordId));
  return EffectiveSendOffSet(effective);
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

SendOffDependencyStatus _dependencyStatus({
  required MatchRecord sendOff,
  required DisciplinarySubjectRef subject,
  required DisciplinaryAccountingScope scope,
  required Map<String, MatchRecord> recordsById,
  required EffectiveYellowResolution yellowResolution,
}) {
  final payload = sendOff.payload as SendOffPayload;
  final causal = [
    for (final link in sendOff.relationships)
      if (link is CausalDependency) link.targetRecordId,
  ];
  if (payload.pathway == SendOffPathway.direct) {
    if (payload.firstStandingCautionRecordId != null ||
        payload.secondCautionRecordId != null ||
        causal.isNotEmpty) {
      return SendOffDependencyStatus.unavailable;
    }
    return SendOffDependencyStatus.ready;
  }

  final first = payload.firstStandingCautionRecordId;
  final second = payload.secondCautionRecordId;
  if (first == null || second == null || first == second) {
    return SendOffDependencyStatus.unavailable;
  }
  final causalSet = causal.toSet();
  if (causal.length != causalSet.length ||
      causalSet.length != 2 ||
      !causalSet.contains(first) ||
      !causalSet.contains(second)) {
    return SendOffDependencyStatus.unavailable;
  }
  if (yellowResolution is EffectiveYellowConflicted) {
    return SendOffDependencyStatus.conflicted;
  }
  if (yellowResolution is EffectiveYellowUnavailable) {
    return SendOffDependencyStatus.unavailable;
  }
  final yellows = {
    for (final yellow in (yellowResolution as EffectiveYellowSet).yellows)
      yellow.yellowRecordId: yellow,
  };
  final y1 = recordsById[first];
  final y2 = recordsById[second];
  if (y1 == null || y2 == null) return SendOffDependencyStatus.unavailable;
  if (!isYellowCardPayload(y1.payload) || !isYellowCardPayload(y2.payload)) {
    return SendOffDependencyStatus.unavailable;
  }
  final effectiveY1 = yellows[first];
  final effectiveY2 = yellows[second];
  if (effectiveY1 == null || effectiveY2 == null) {
    return SendOffDependencyStatus.unavailable;
  }
  if (effectiveY1.subject != subject ||
      effectiveY2.subject != subject ||
      effectiveY1.accountingScope != scope ||
      effectiveY2.accountingScope != scope) {
    return SendOffDependencyStatus.unavailable;
  }
  return SendOffDependencyStatus.ready;
}

final class _SendOffWalk {
  const _SendOffWalk._({required this.cycle, this.sendOffId});

  const _SendOffWalk.cycle() : this._(cycle: true);

  const _SendOffWalk.sendOff(String sendOffId)
      : this._(cycle: false, sendOffId: sendOffId);

  const _SendOffWalk.notASendOff() : this._(cycle: false);

  final bool cycle;
  final String? sendOffId;
}

_SendOffWalk _walkToSendOff(
  String recordId,
  Map<String, MatchRecord> recordsById,
) {
  final visiting = <String>{};
  var current = recordId;
  while (true) {
    if (visiting.contains(current)) return const _SendOffWalk.cycle();
    visiting.add(current);
    final record = recordsById[current];
    if (record == null) return const _SendOffWalk.notASendOff();
    if (record.payload is SendOffPayload) return _SendOffWalk.sendOff(current);
    if (record.recordKind == RecordKind.correction) {
      final next = correctionTargetOf(record);
      if (next == null) return const _SendOffWalk.notASendOff();
      current = next;
      continue;
    }
    return const _SendOffWalk.notASendOff();
  }
}
