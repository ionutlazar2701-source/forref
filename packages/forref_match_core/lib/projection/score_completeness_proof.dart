import '../authority.dart';
import '../authority_root.dart';
import '../match_authority_mode.dart';
import '../match_record.dart';
import '../match_team.dart';
import '../reference/reference_match_memory.dart';
import '../semantics/v1_semantic_payload.dart';

/// External positive inputs required before a [KnownScore] may be emitted.
final class ScoreCompletenessProof {
  const ScoreCompletenessProof({
    required this.matchAuthorityMode,
    required this.teamBindings,
    required this.generationOneRoot,
  });

  final MatchAuthorityMode matchAuthorityMode;
  final List<MatchTeamBinding> teamBindings;
  final GenerationOneAuthorityRoot generationOneRoot;
}

/// Validates proof inputs and committed-record evidence for score completeness.
ScoreProofValidation validateScoreCompletenessProof({
  required String matchId,
  required List<MatchRecord> sortedRecords,
  required ScoreCompletenessProof? proof,
  required bool scoreAuthorityConflict,
  required bool scoreCorrectionConflict,
  required bool scoreMissingDependency,
  required List<String> unsupportedSemanticRecordIds,
  required List<String> missingDependencyTargets,
}) {
  if (proof == null) {
    return const ScoreProofValidation.unavailable();
  }
  if (proof.matchAuthorityMode != MatchAuthorityMode.matchMemory) {
    return const ScoreProofValidation.unavailable();
  }
  if (proof.generationOneRoot.matchId != matchId) {
    return const ScoreProofValidation.unavailable();
  }
  if (proof.generationOneRoot.generation != 1 ||
      !proof.generationOneRoot.predecessorAbsent) {
    return const ScoreProofValidation.unavailable();
  }

  final bindings = proof.teamBindings
      .where((binding) => binding.matchId == matchId)
      .map((binding) => binding.teamId)
      .toSet();
  if (bindings.length != 2) {
    return const ScoreProofValidation.unavailable();
  }

  if (scoreAuthorityConflict || scoreCorrectionConflict) {
    return const ScoreProofValidation.conflicted();
  }
  if (scoreMissingDependency || missingDependencyTargets.isNotEmpty) {
    return const ScoreProofValidation.unavailable();
  }
  if (unsupportedSemanticRecordIds.isNotEmpty) {
    return const ScoreProofValidation.unavailable();
  }

  final rootDevice = proof.generationOneRoot.deviceId;
  final sequencesByOrigin = <String, Set<int>>{};
  var sawGenerationOnePrincipal = false;
  for (final record in sortedRecords) {
    if (record.matchId != matchId) continue;
    if (record.integrity.evidenceRefs.isEmpty) {
      return const ScoreProofValidation.unavailable();
    }
    if (_generationOneCapture(record.payload) &&
        record.authorityContext?.generation?.value != 1) {
      return const ScoreProofValidation.unavailable();
    }
    sequencesByOrigin
        .putIfAbsent(record.originDeviceId, () => <int>{})
        .add(record.originSequence);
    final authority = record.authorityContext;
    if (authority?.scope is MainRefereeScope &&
        authority?.generation?.value == 1 &&
        authority?.principal?.principalId ==
            proof.generationOneRoot.principalId) {
      sawGenerationOnePrincipal = true;
    }
  }

  if (!sawGenerationOnePrincipal) {
    return const ScoreProofValidation.unavailable();
  }

  for (final origin in sequencesByOrigin.entries) {
    if (origin.key != rootDevice) {
      return const ScoreProofValidation.unavailable();
    }
    final frontier = _frontierFromSequences(
      matchId: matchId,
      originDeviceId: origin.key,
      sequences: origin.value,
    );
    if (frontier.missingSequences.isNotEmpty) {
      return const ScoreProofValidation.unavailable();
    }
  }
  if (sortedRecords.isEmpty) {
    return const ScoreProofValidation.unavailable();
  }

  return ScoreProofValidation.ready(teamIds: bindings.toList());
}

bool _generationOneCapture(Object payload) {
  return payload is GoalPayload ||
      payload is YellowCardPayload ||
      payload is YellowCardPayloadV2 ||
      payload is SendOffPayload ||
      payload is RefereeEnteredFieldPayload;
}

final class ScoreProofValidation {
  const ScoreProofValidation._({
    required this.ready,
    required this.conflicted,
    required this.teamIds,
  });

  const ScoreProofValidation.unavailable()
      : this._(ready: false, conflicted: false, teamIds: const []);

  const ScoreProofValidation.conflicted()
      : this._(ready: false, conflicted: true, teamIds: const []);

  const ScoreProofValidation.ready({required List<MatchTeamId> teamIds})
      : this._(ready: true, conflicted: false, teamIds: teamIds);

  final bool ready;
  final bool conflicted;
  final List<MatchTeamId> teamIds;
}

OriginSequenceFrontier _frontierFromSequences({
  required String matchId,
  required String originDeviceId,
  required Set<int> sequences,
}) {
  final sorted = sequences.toList()..sort();
  final highestObserved = sorted.isEmpty ? 0 : sorted.last;

  var highestContiguous = 0;
  for (var sequence = 1; sequence <= highestObserved; sequence++) {
    if (!sequences.contains(sequence)) break;
    highestContiguous = sequence;
  }

  final missing = <int>[];
  for (var sequence = 1; sequence <= highestObserved; sequence++) {
    if (!sequences.contains(sequence)) missing.add(sequence);
  }

  return OriginSequenceFrontier(
    matchId: matchId,
    originDeviceId: originDeviceId,
    committedSequences: sorted,
    highestContiguousCommitted: highestContiguous,
    highestObserved: highestObserved,
    missingSequences: missing,
  );
}
