import 'state.dart';

/// Derives presentation score from established goals only.
ScorePresentation scoreFromGoalCounts({
  required int homeGoals,
  required int awayGoals,
  required String homeTeamLabel,
  required String awayTeamLabel,
}) {
  return ScorePresentation(
    available: true,
    label: '$homeGoals – $awayGoals',
    homeGoals: homeGoals,
    awayGoals: awayGoals,
  );
}

int homeGoalsFromCounts(int homeGoals, int awayGoals) => homeGoals;

/// Builds chronological match report entries from goal rows.
MatchReportPresentation matchReportFromGoals(
  List<({
    String eventId,
    int sequence,
    String matchTimeLabel,
    String teamLabel,
    String participantDisplay,
    String scoreAfterLabel,
    String originTrace,
  })> goals,
) {
  final sorted = [...goals]..sort((a, b) => a.sequence.compareTo(b.sequence));
  return MatchReportPresentation(
    entries: [
      for (final goal in sorted)
        MatchReportEntryPresentation(
          eventId: goal.eventId,
          sequence: goal.sequence,
          kind: MatchReportEntryKind.goal,
          matchTimeLabel: goal.matchTimeLabel,
          teamLabel: goal.teamLabel,
          participantDisplay: goal.participantDisplay,
          scoreAfterLabel: goal.scoreAfterLabel,
          originTrace: goal.originTrace,
        ),
    ],
  );
}
