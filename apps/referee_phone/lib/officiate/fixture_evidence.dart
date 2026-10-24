import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';

import '../infrastructure/identity/phone_capture_identity.dart';
import '../match_application/match_application_boundary.dart';
import 'fixture_list.dart';

/// Reads start and normal-end from Match Memory.
///
/// A missing boundary, or a failed read, stays [FixtureEvidence.none].
/// That does not mark the fixture current.
Future<FixtureEvidence> loadFixtureEvidence({
  required MatchApplicationBoundary? boundary,
  required String matchId,
}) async {
  if (boundary == null) return const FixtureEvidence.none();
  try {
    final records = await boundary.durableStore.readCommittedForMatch(matchId);
    final projection = await boundary.project(
      matchId,
      evaluatedAuthorityGeneration:
          PhoneCaptureIdentity.initialAuthorityGeneration,
    );
    final temporal = TemporalMatchProjection.derive(
      projection: projection,
      records: records,
    );
    return FixtureEvidence(
      authoritativelyStarted: temporal.matchStarted,
      authoritativelyEnded: temporal.matchNormallyEnded,
    );
  } catch (_) {
    return const FixtureEvidence.none();
  }
}

/// Classifies [matches] from Match Memory.
///
/// Stops without a partial result when [cancelled] becomes true, so a newer
/// reload is not overwritten by an older read.
Future<List<ListedFixture>> fixturesWithEvidence({
  required MatchApplicationBoundary? boundary,
  required List<Match> matches,
  required bool Function() cancelled,
}) async {
  final fixtures = <ListedFixture>[];
  for (final match in matches) {
    if (cancelled()) return const [];
    fixtures.add(
      ListedFixture(
        match: match,
        evidence: await loadFixtureEvidence(
          boundary: boundary,
          matchId: match.matchId,
        ),
      ),
    );
  }
  if (cancelled()) return const [];
  return fixtures;
}
