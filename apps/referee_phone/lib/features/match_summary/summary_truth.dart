import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';

/// What Match Summary may present.
///
/// A missing boundary, an unreadable score, and a conflicted score do not
/// borrow numerals, the clock, or the event list from the mutable match.
/// [known] is a [KnownScore] projection. It is not a match-ended record.
enum SummaryEvidence { boundaryMissing, unavailable, conflicted, known }

final class SummaryTruth {
  const SummaryTruth({
    required this.evidence,
    this.homeGoals,
    this.awayGoals,
    required this.showMutableTimeline,
    required this.showLegacyFinish,
  });

  final SummaryEvidence evidence;
  final int? homeGoals;
  final int? awayGoals;

  /// Mutable elapsed time and events. Shown only beside a known score.
  final bool showMutableTimeline;

  /// Legacy full-time completion. Not a MATCH_ENDED record.
  final bool showLegacyFinish;

  bool get showProjectedScore =>
      evidence == SummaryEvidence.known &&
      homeGoals != null &&
      awayGoals != null;
}

SummaryTruth summarizeMatchTruth({
  required bool boundaryPresent,
  required ScoreProjection? projection,
  required MatchStatus legacyStatus,
  required String homeTeamId,
  required String awayTeamId,
}) {
  if (!boundaryPresent) {
    return const SummaryTruth(
      evidence: SummaryEvidence.boundaryMissing,
      showMutableTimeline: false,
      showLegacyFinish: false,
    );
  }
  if (projection is ScoreConflicted) {
    return const SummaryTruth(
      evidence: SummaryEvidence.conflicted,
      showMutableTimeline: false,
      showLegacyFinish: false,
    );
  }
  if (projection is KnownScore) {
    final home = projection.goalsByTeam[MatchTeamId(homeTeamId)];
    final away = projection.goalsByTeam[MatchTeamId(awayTeamId)];
    if (home == null || away == null) {
      return const SummaryTruth(
        evidence: SummaryEvidence.unavailable,
        showMutableTimeline: false,
        showLegacyFinish: false,
      );
    }
    return SummaryTruth(
      evidence: SummaryEvidence.known,
      homeGoals: home,
      awayGoals: away,
      showMutableTimeline: true,
      showLegacyFinish: legacyStatus == MatchStatus.fullTime,
    );
  }
  return const SummaryTruth(
    evidence: SummaryEvidence.unavailable,
    showMutableTimeline: false,
    showLegacyFinish: false,
  );
}
