import 'package:match_core/match_core.dart';

import 'match_application_boundary.dart';

/// Phone read path. This does not select a writable authority.
enum MatchReadPath {
  matchMemory,
  legacyOnly,
  unknown,
  ambiguous,
  unavailable,
}

/// Legacy Drift events or a non-zero legacy score are a sporting history.
bool legacySportingHistory(Match? match) {
  if (match == null) return false;
  return match.events.isNotEmpty ||
      match.score.home != 0 ||
      match.score.away != 0;
}

/// Classifies a match from root and committed-row evidence.
///
/// No persisted per-match mode exists. Unknown stays unknown.
MatchReadPath classifyMatchReadPath({
  required MatchMemoryEvidence? evidence,
  required bool legacyMatchPresent,
  required bool legacySportingHistory,
}) {
  if (evidence == null) {
    return legacyMatchPresent
        ? MatchReadPath.legacyOnly
        : MatchReadPath.unknown;
  }
  if (!evidence.readable) return MatchReadPath.unavailable;
  final memory = evidence.rootPresent && evidence.committedCount > 0;
  final recordsWithoutRoot =
      !evidence.rootPresent && evidence.committedCount > 0;
  if (recordsWithoutRoot) return MatchReadPath.ambiguous;
  if (memory && legacySportingHistory) return MatchReadPath.ambiguous;
  if (memory) return MatchReadPath.matchMemory;
  if (evidence.rootPresent && evidence.committedCount == 0) {
    return MatchReadPath.unknown;
  }
  if (legacyMatchPresent) return MatchReadPath.legacyOnly;
  return MatchReadPath.unknown;
}

/// Loads read-path evidence. Unexpected store errors propagate to the caller.
Future<MatchReadPath> resolveMatchReadPath({
  required MatchApplicationBoundary? boundary,
  required Match? legacyMatch,
  required String matchId,
}) async {
  final MatchMemoryEvidence? evidence =
      boundary == null ? null : await boundary.readMatchMemoryEvidence(matchId);
  return classifyMatchReadPath(
    evidence: evidence,
    legacyMatchPresent: legacyMatch != null,
    legacySportingHistory: legacySportingHistory(legacyMatch),
  );
}
