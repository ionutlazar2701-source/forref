import 'package:match_core/match_core.dart';

import '../infrastructure/database/local_match_database.dart';
import '../infrastructure/identity/phone_capture_identity.dart';
import '../match_application/match_application_boundary.dart';
import '../officiate/fixture_evidence.dart';
import '../officiate/fixture_list.dart';
import 'training_session.dart';

/// Legacy full time is not, by itself, a running match.
///
/// An authoritative start that has not authoritatively ended still blocks.
/// This does not mark the match complete and does not write Match Memory.
bool trainingMatchStillRunning({
  required Match match,
  required FixtureEvidence evidence,
}) {
  if (evidence.authoritativelyEnded) return false;
  if (evidence.authoritativelyStarted) return true;
  return match.status == MatchStatus.live ||
      match.status == MatchStatus.paused ||
      match.status == MatchStatus.halfTime;
}

/// Reads match evidence before a training start.
///
/// A failed Match Memory read blocks the start. This does not write a match
/// and does not stop a match that is already open.
Future<TrainingStartDenial?> trainingMatchDenial({
  required LocalMatchDatabase database,
  required MatchApplicationBoundary? boundary,
  required DateTime today,
  required bool anotherSessionOpen,
}) async {
  final List<Match> matches;
  try {
    matches = await database.listNewestFirst();
  } catch (_) {
    return denyTrainingStart(
      anotherSessionOpen: anotherSessionOpen,
      matchInProgress: false,
      matchStateUnverified: true,
    );
  }
  var inProgress = false;
  var unverified = false;
  for (final match in matches) {
    if (boundary != null) {
      try {
        await boundary.durableStore.readCommittedForMatch(match.matchId);
        await boundary.project(
          match.matchId,
          evaluatedAuthorityGeneration:
              PhoneCaptureIdentity.initialAuthorityGeneration,
        );
      } catch (_) {
        unverified = true;
        break;
      }
    }
    final evidence = await loadFixtureEvidence(
      boundary: boundary,
      matchId: match.matchId,
    );
    if (trainingMatchStillRunning(match: match, evidence: evidence)) {
      inProgress = true;
    }
  }
  return denyTrainingStart(
    anotherSessionOpen: anotherSessionOpen,
    matchInProgress: inProgress,
    matchStateUnverified: unverified,
  );
}
