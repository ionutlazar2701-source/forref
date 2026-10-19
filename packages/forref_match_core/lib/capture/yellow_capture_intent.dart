import '../disciplinary_subject.dart';
import '../match_participant.dart';
import '../match_record.dart';
import '../semantics/v1_semantic_payload.dart';
import 'capture_intent.dart';

/// Irreversible Yellow meaning bound to one [CaptureIntentKey].
///
/// Subject category is part of the meaning. A participant token and a
/// team-official token do not match.
final class YellowCaptureIntentMeaning {
  YellowCaptureIntentMeaning({
    MatchParticipantId? participantId,
    DisciplinarySubjectRef? disciplinarySubject,
    required this.accountingScope,
    required this.authorityPrincipalId,
    required this.authorityGeneration,
  }) : disciplinarySubject = _subject(
          participantId: participantId,
          disciplinarySubject: disciplinarySubject,
        );

  final DisciplinarySubjectRef disciplinarySubject;
  final DisciplinaryAccountingScope accountingScope;
  final String authorityPrincipalId;
  final int authorityGeneration;

  static DisciplinarySubjectRef _subject({
    required MatchParticipantId? participantId,
    required DisciplinarySubjectRef? disciplinarySubject,
  }) {
    final fromParticipant = participantId == null
        ? null
        : ParticipantDisciplinarySubject(participantId);
    if (disciplinarySubject != null &&
        fromParticipant != null &&
        disciplinarySubject != fromParticipant) {
      throw ArgumentError('Yellow subject category is ambiguous');
    }
    final subject = disciplinarySubject ?? fromParticipant;
    if (subject == null) {
      throw ArgumentError('Yellow capture intent requires a subject');
    }
    return subject;
  }

  @override
  bool operator ==(Object other) =>
      other is YellowCaptureIntentMeaning &&
      disciplinarySubject == other.disciplinarySubject &&
      accountingScope == other.accountingScope &&
      authorityPrincipalId == other.authorityPrincipalId &&
      authorityGeneration == other.authorityGeneration;

  @override
  int get hashCode => Object.hash(
        disciplinarySubject,
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
      YellowCardPayloadV2() => payload.captureIntentId,
      SendOffPayload() => payload.captureIntentId,
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
  if (!isYellowCardPayload(payload)) {
    return YellowCaptureIntentConflict(existingRecordId: existing.recordId);
  }
  final existingMeaning = YellowCaptureIntentMeaning(
    disciplinarySubject: subjectOfYellowCard(payload),
    accountingScope: scopeOfYellowCard(payload),
    authorityPrincipalId:
        existing.authorityContext?.principal?.principalId ?? '',
    authorityGeneration: existing.authorityContext?.generation?.value ?? 0,
  );
  if (existingMeaning == requestedMeaning) {
    return YellowCaptureIntentIdempotent(existingRecordId: existing.recordId);
  }
  return YellowCaptureIntentConflict(existingRecordId: existing.recordId);
}
