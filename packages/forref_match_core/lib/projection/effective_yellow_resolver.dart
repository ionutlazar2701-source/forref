import '../match_participant.dart';
import '../match_record.dart';
import '../record_kind.dart';
import '../semantics/v1_semantic_payload.dart';
import 'effective_goal_resolver.dart';

/// One Yellow whose current description and standing follow the generic resolver.
final class EffectiveYellow {
  const EffectiveYellow({
    required this.yellowRecordId,
    required this.participantId,
    required this.accountingScope,
    required this.standing,
  });

  final String yellowRecordId;
  final MatchParticipantId participantId;
  final DisciplinaryAccountingScope accountingScope;
  final bool standing;
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
      .where((record) => record.payload is YellowCardPayload)
      .toList()
    ..sort((a, b) => a.recordId.compareTo(b.recordId));

  final participantByYellow = <String, MatchParticipantId>{};
  final scopeByYellow = <String, DisciplinaryAccountingScope>{};
  for (final yellow in yellowRecords) {
    final payload = yellow.payload as YellowCardPayload;
    participantByYellow[yellow.recordId] = payload.participantId;
    scopeByYellow[yellow.recordId] = payload.accountingScope;
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

  final repairedParticipants = <String, Set<MatchParticipantId>>{};
  final repairedScopes = <String, Set<DisciplinaryAccountingScope>>{};
  for (final correction in correctionRecords) {
    final payload = correction.payload as CorrectionPayload;
    if (payload.repairedParticipantId == null &&
        payload.repairedAccountingScope == null) {
      continue;
    }
    final walk = _walkToYellow(correctionTargetOf(correction)!, recordsById);
    if (walk.cycle) return const EffectiveYellowUnavailable();
    final yellowId = walk.yellowId;
    if (yellowId == null) continue;
    if (payload.repairedParticipantId != null) {
      repairedParticipants
          .putIfAbsent(yellowId, () => {})
          .add(payload.repairedParticipantId!);
    }
    if (payload.repairedAccountingScope != null) {
      repairedScopes
          .putIfAbsent(yellowId, () => {})
          .add(payload.repairedAccountingScope!);
    }
  }
  for (final entry in repairedParticipants.entries) {
    if (entry.value.length > 1) return const EffectiveYellowConflicted();
    participantByYellow[entry.key] = entry.value.first;
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
        participantId: participantByYellow[yellow.recordId]!,
        accountingScope: scopeByYellow[yellow.recordId]!,
        standing: !voided,
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
  final payload = correction.payload;
  if (payload is CorrectionPayload &&
      (payload.repairedParticipantId != null ||
          payload.repairedAccountingScope != null)) {
    return true;
  }
  return _walkToYellow(correction.recordId, recordsById).yellowId != null;
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
    if (record.payload is YellowCardPayload) {
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
