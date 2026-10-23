import 'state.dart';

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

/// Builds chronological Match Report from established research rows.
MatchReportPresentation buildMatchReport({
  required List<MatchReportEntryPresentation> entries,
}) {
  final sorted = [...entries]..sort((a, b) => a.sequence.compareTo(b.sequence));
  return MatchReportPresentation(entries: sorted);
}

String matchReportKindLabel(MatchReportEntryKind kind) {
  return switch (kind) {
    MatchReportEntryKind.goal => 'GOAL',
    MatchReportEntryKind.yellow => 'YELLOW',
    MatchReportEntryKind.directSendOff => 'SEND-OFF · DIRECT',
    MatchReportEntryKind.secondCautionSendOff => 'SEND-OFF · SECOND CAUTION',
    MatchReportEntryKind.substitution => 'SUBSTITUTION',
  };
}
