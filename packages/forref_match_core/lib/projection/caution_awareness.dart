import '../disciplinary_subject.dart';
import '../match_participant.dart';
import '../match_record.dart';
import '../semantics/v1_semantic_payload.dart';
import 'effective_send_off_resolver.dart';
import 'effective_yellow_resolver.dart';
import 'score_completeness_proof.dart';

/// Read-only caution answer for one participant in one accounting scope.
///
/// Opening this value does not append Match Records. A count exists only on
/// [KnownStandingCaution]. [KnownNoStandingCaution] is a positive proof of
/// none, including the case where every caution for that subject is historical.
sealed class CautionAwareness {
  const CautionAwareness();
}

final class KnownStandingCaution extends CautionAwareness {
  KnownStandingCaution({
    required this.standingCount,
    required List<String> historicalYellowRecordIds,
    required List<String> standingYellowRecordIds,
    required this.activeCautionSurface,
  })  : historicalYellowRecordIds =
            List.unmodifiable(historicalYellowRecordIds),
        standingYellowRecordIds = List.unmodifiable(standingYellowRecordIds);

  final int standingCount;
  final List<String> historicalYellowRecordIds;
  final List<String> standingYellowRecordIds;

  /// False when an effective explicit SEND_OFF removes future-caution membership.
  ///
  /// Historical caution ids stay on this value. This flag does not commit SEND_OFF.
  final bool activeCautionSurface;

  /// Factual awareness only. This value does not commit SEND_OFF.
  bool get secondCautionSituation => standingCount >= 2;
}

final class KnownNoStandingCaution extends CautionAwareness {
  KnownNoStandingCaution({
    required List<String> historicalYellowRecordIds,
    required this.activeCautionSurface,
  }) : historicalYellowRecordIds =
            List.unmodifiable(historicalYellowRecordIds);

  final List<String> historicalYellowRecordIds;

  /// False when an effective explicit SEND_OFF removes future-caution membership.
  final bool activeCautionSurface;
}

final class CautionAwarenessUnavailable extends CautionAwareness {
  const CautionAwarenessUnavailable();
}

final class CautionAwarenessConflicted extends CautionAwareness {
  const CautionAwarenessConflicted();
}

/// Participant adapter. The subject key is [ParticipantDisciplinarySubject].
CautionAwareness assessCautionAwareness({
  required String matchId,
  required MatchParticipantId participantId,
  required DisciplinaryAccountingScope accountingScope,
  required List<MatchRecord> records,
  required ScoreCompletenessProof? proof,
  required bool authorityConflict,
  required bool correctionConflict,
  required bool missingDependency,
  required List<String> unsupportedSemanticRecordIds,
  required List<String> missingDependencyTargets,
}) {
  return assessDisciplinaryAwareness(
    matchId: matchId,
    subject: ParticipantDisciplinarySubject(participantId),
    accountingScope: accountingScope,
    records: records,
    proof: proof,
    authorityConflict: authorityConflict,
    correctionConflict: correctionConflict,
    missingDependency: missingDependency,
    unsupportedSemanticRecordIds: unsupportedSemanticRecordIds,
    missingDependencyTargets: missingDependencyTargets,
  );
}

/// One evaluator for a participant or a team official.
///
/// Opening this value appends no Match Records.
CautionAwareness assessDisciplinaryAwareness({
  required String matchId,
  required DisciplinarySubjectRef subject,
  required DisciplinaryAccountingScope accountingScope,
  required List<MatchRecord> records,
  required ScoreCompletenessProof? proof,
  required bool authorityConflict,
  required bool correctionConflict,
  required bool missingDependency,
  required List<String> unsupportedSemanticRecordIds,
  required List<String> missingDependencyTargets,
}) {
  final sorted = [...records]..sort((a, b) {
      final byOrigin = a.originDeviceId.compareTo(b.originDeviceId);
      if (byOrigin != 0) return byOrigin;
      final bySequence = a.originSequence.compareTo(b.originSequence);
      if (bySequence != 0) return bySequence;
      return a.recordId.compareTo(b.recordId);
    });
  final proofCheck = validateAuthoritativeHistoryCompleteness(
    matchId: matchId,
    sortedRecords: sorted,
    evidence: proof,
    authorityConflict: authorityConflict,
    correctionConflict: correctionConflict,
    missingDependency: missingDependency,
    unsupportedSemanticRecordIds: unsupportedSemanticRecordIds,
    missingDependencyTargets: missingDependencyTargets,
  );
  if (!proofCheck.ready || proofCheck.conflicted) {
    return proofCheck.conflicted
        ? const CautionAwarenessConflicted()
        : const CautionAwarenessUnavailable();
  }

  final recordsById = {for (final record in records) record.recordId: record};
  final resolved = resolveEffectiveYellows(recordsById: recordsById);
  if (resolved is EffectiveYellowConflicted) {
    return const CautionAwarenessConflicted();
  }
  if (resolved is EffectiveYellowUnavailable) {
    return const CautionAwarenessUnavailable();
  }
  final yellows = (resolved as EffectiveYellowSet).yellows.where((yellow) {
    final record = recordsById[yellow.yellowRecordId]!;
    return record.matchId == matchId &&
        yellow.subject == subject &&
        yellow.accountingScope == accountingScope;
  }).toList();

  final historical = [
    for (final yellow in yellows) yellow.yellowRecordId,
  ]..sort();
  final standing = [
    for (final yellow in yellows)
      if (yellow.standing) yellow.yellowRecordId,
  ]..sort();
  final sendOffResolution = resolveEffectiveSendOffs(recordsById: recordsById);
  if (sendOffResolution is EffectiveSendOffConflicted) {
    return const CautionAwarenessConflicted();
  }
  if (sendOffResolution is EffectiveSendOffUnavailable) {
    return const CautionAwarenessUnavailable();
  }
  final activeSendOffs = (sendOffResolution as EffectiveSendOffSet)
      .sendOffs
      .where((sendOff) {
        final record = recordsById[sendOff.sendOffRecordId];
        return record != null &&
            record.matchId == matchId &&
            sendOff.legallyEffective &&
            sendOff.subject == subject &&
            sendOff.scope == accountingScope;
      }).toList();
  for (final sendOff in activeSendOffs) {
    if (sendOff.dependencyStatus == SendOffDependencyStatus.conflicted) {
      return const CautionAwarenessConflicted();
    }
    if (sendOff.dependencyStatus == SendOffDependencyStatus.unavailable) {
      return const CautionAwarenessUnavailable();
    }
  }
  final activeCautionSurface = activeSendOffs.isEmpty;

  if (standing.isEmpty) {
    return KnownNoStandingCaution(
      historicalYellowRecordIds: historical,
      activeCautionSurface: activeCautionSurface,
    );
  }
  return KnownStandingCaution(
    standingCount: standing.length,
    historicalYellowRecordIds: historical,
    standingYellowRecordIds: standing,
    activeCautionSurface: activeCautionSurface,
  );
}
