import '../authority.dart';
import '../match_participant.dart';
import '../match_record.dart';
import '../semantics/v1_semantic_payload.dart';
import 'capture_intent.dart';

/// Irreversible Yellow meaning bound to one [CaptureIntentKey].
final class YellowCaptureIntentMeaning {
  const YellowCaptureIntentMeaning({
    required this.participantId,
    required this.accountingScope,
    required this.authorityPrincipalId,
    required this.authorityGeneration,
  });

  final MatchParticipantId participantId;
  final DisciplinaryAccountingScope accountingScope;
  final String authorityPrincipalId;
  final int authorityGeneration;

  @override
  bool operator ==(Object other) =>
      other is YellowCaptureIntentMeaning &&
      participantId == other.participantId &&
      accountingScope == other.accountingScope &&
      authorityPrincipalId == other.authorityPrincipalId &&
      authorityGeneration == other.authorityGeneration;

  @override
  int get hashCode => Object.hash(
        participantId,
        accountingScope,
        authorityPrincipalId,
        authorityGeneration,
      );
}

sealed class YellowCaptureIntentAdmission {
  const YellowCaptureIntentAdmission();
}

final class YellowCaptureIntentFirstAdmission
    extends YellowCaptureIntentAdmission {
  const YellowCaptureIntentFirstAdmission();
}

final class YellowCaptureIntentIdempotent extends YellowCaptureIntentAdmission {
  const YellowCaptureIntentIdempotent({required this.existingRecordId});

  final String existingRecordId;
}

final class YellowCaptureIntentConflict extends YellowCaptureIntentAdmission {
  const YellowCaptureIntentConflict({required this.existingRecordId});

  final String existingRecordId;
}

/// Same intent and same subject/scope are idempotent. A different subject,
/// scope, or semantic is a conflict. No proximity deduplication.
YellowCaptureIntentAdmission evaluateYellowCaptureIntentAdmission({
  required CaptureIntentKey key,
  required YellowCaptureIntentMeaning requestedMeaning,
  required Iterable<MatchRecord> committedForMatch,
}) {
  MatchRecord? existing;
  for (final record in committedForMatch) {
    if (record.matchId != key.matchId) continue;
    final payload = record.payload;
    final intentId = switch (payload) {
      GoalPayload() => payload.captureIntentId,
      YellowCardPayload() => payload.captureIntentId,
      RefereeEnteredFieldPayload() => payload.captureIntentId,
      _ => null,
    };
    if (intentId != key.captureIntentId) continue;
    if (record.authorityContext?.scope != key.authorityScope) continue;
    existing = record;
    break;
  }
  if (existing == null) return const YellowCaptureIntentFirstAdmission();
  final payload = existing.payload;
  if (payload is! YellowCardPayload) {
    return YellowCaptureIntentConflict(existingRecordId: existing.recordId);
  }
  final existingMeaning = YellowCaptureIntentMeaning(
    participantId: payload.participantId,
    accountingScope: payload.accountingScope,
    authorityPrincipalId:
        existing.authorityContext?.principal?.principalId ?? '',
    authorityGeneration: existing.authorityContext?.generation?.value ?? 0,
  );
  if (existingMeaning == requestedMeaning) {
    return YellowCaptureIntentIdempotent(existingRecordId: existing.recordId);
  }
  return YellowCaptureIntentConflict(existingRecordId: existing.recordId);
}
