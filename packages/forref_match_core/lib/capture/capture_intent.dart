import '../authority.dart';
import '../match_record.dart';
import '../match_team.dart';
import '../semantics/match_record_semantic_type.dart';
import '../semantics/v1_semantic_payload.dart';

/// Capture intent identity: one durable command slot per match and scope.
final class CaptureIntentKey {
  CaptureIntentKey({
    required this.matchId,
    required this.authorityScope,
    required String captureIntentId,
  }) : captureIntentId = _nonEmpty(captureIntentId);

  static String _nonEmpty(String value) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, 'captureIntentId', 'cannot be empty');
    }
    return value;
  }

  final String matchId;
  final AuthorityScope authorityScope;
  final String captureIntentId;

  @override
  bool operator ==(Object other) =>
      other is CaptureIntentKey &&
      matchId == other.matchId &&
      authorityScope == other.authorityScope &&
      captureIntentId == other.captureIntentId;

  @override
  int get hashCode => Object.hash(matchId, authorityScope, captureIntentId);
}

/// Irreversible sporting meaning bound to one [CaptureIntentKey] for Goal.
final class CaptureIntentMeaning {
  const CaptureIntentMeaning({
    required this.semanticType,
    required this.authorityPrincipalId,
    required this.authorityGeneration,
    required this.scoringTeamId,
  }) : assert(authorityGeneration >= 1);

  final V1SemanticTypeCode semanticType;
  final String authorityPrincipalId;
  final int authorityGeneration;
  final MatchTeamId scoringTeamId;

  @override
  bool operator ==(Object other) =>
      other is CaptureIntentMeaning &&
      semanticType == other.semanticType &&
      authorityPrincipalId == other.authorityPrincipalId &&
      authorityGeneration == other.authorityGeneration &&
      scoringTeamId == other.scoringTeamId;

  @override
  int get hashCode => Object.hash(
        semanticType,
        authorityPrincipalId,
        authorityGeneration,
        scoringTeamId,
      );
}

/// Outcome of comparing a proposed Goal against an existing committed Goal.
sealed class CaptureIntentAdmission {
  const CaptureIntentAdmission();
}

/// No prior record for this key.
final class CaptureIntentFirstAdmission extends CaptureIntentAdmission {
  const CaptureIntentFirstAdmission();
}

/// Same key and same irreversible meaning — idempotent success.
final class CaptureIntentIdempotent extends CaptureIntentAdmission {
  const CaptureIntentIdempotent({required this.existingRecordId});

  final String existingRecordId;
}

/// Same key but a different team or semantic — fail closed.
final class CaptureIntentConflict extends CaptureIntentAdmission {
  const CaptureIntentConflict({
    required this.existingRecordId,
    required this.existingMeaning,
    required this.requestedMeaning,
  });

  final String existingRecordId;
  final CaptureIntentMeaning existingMeaning;
  final CaptureIntentMeaning requestedMeaning;
}

/// Pure capture-intent evaluation. No timestamp deduplication.
CaptureIntentAdmission evaluateCaptureIntentAdmission({
  required CaptureIntentKey key,
  required CaptureIntentMeaning requestedMeaning,
  required Iterable<MatchRecord> committedForMatch,
}) {
  MatchRecord? existing;
  for (final record in committedForMatch) {
    if (record.matchId != key.matchId) continue;
    final payload = record.payload;
    if (payload is! GoalPayload) continue;
    if (payload.captureIntentId != key.captureIntentId) continue;
    final authority = record.authorityContext;
    if (authority?.scope != key.authorityScope) continue;
    existing = record;
    break;
  }

  if (existing == null) {
    return const CaptureIntentFirstAdmission();
  }

  final existingMeaning = captureIntentMeaningFromGoalRecord(existing);
  if (existingMeaning == requestedMeaning) {
    return CaptureIntentIdempotent(existingRecordId: existing.recordId);
  }
  return CaptureIntentConflict(
    existingRecordId: existing.recordId,
    existingMeaning: existingMeaning,
    requestedMeaning: requestedMeaning,
  );
}

/// Builds the bound meaning for a committed Goal record.
CaptureIntentMeaning captureIntentMeaningFromGoalRecord(MatchRecord record) {
  final payload = record.payload as GoalPayload;
  final authority = record.authorityContext;
  return CaptureIntentMeaning(
    semanticType: V1SemanticTypeCode.goal,
    authorityPrincipalId: authority?.principal?.principalId ?? '',
    authorityGeneration: authority?.generation?.value ?? 0,
    scoringTeamId: payload.scoringTeamId,
  );
}
