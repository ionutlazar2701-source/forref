import 'package:match_core/match_core.dart';

import '../infrastructure/database/local_match_database.dart';
import '../infrastructure/identity/phone_capture_identity.dart';
import '../match_application/match_application_boundary.dart';
import '../officiate/fixture_evidence.dart';
import '../officiate/fixture_list.dart';
import 'training_session.dart';

/// Reads fixture classification before a training start.
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
    final group = classifyFixture(
      match: match,
      evidence: evidence,
      today: today,
    );
    if (group == FixtureGroup.current) inProgress = true;
  }
  return denyTrainingStart(
    anotherSessionOpen: anotherSessionOpen,
    matchInProgress: inProgress,
    matchStateUnverified: unverified,
  );
}
