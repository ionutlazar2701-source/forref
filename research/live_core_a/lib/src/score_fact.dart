import 'package:live_core_a/src/fixture_identity.dart';

/// Structured score fact for SCORE trials (team attribution is part of correctness).
class ScoreFact {
  const ScoreFact({
    required this.homeGoals,
    required this.awayGoals,
    required this.homeTeamId,
    required this.awayTeamId,
  });

  final int homeGoals;
  final int awayGoals;
  final OpaqueTeamId homeTeamId;
  final OpaqueTeamId awayTeamId;

  Map<String, Object?> toJson() => {
        'homeGoals': homeGoals,
        'awayGoals': awayGoals,
        'homeTeamId': homeTeamId.value,
        'awayTeamId': awayTeamId.value,
      };

  static ScoreFact fromJson(Map<String, Object?> json) {
    return ScoreFact(
      homeGoals: json['homeGoals']! as int,
      awayGoals: json['awayGoals']! as int,
      homeTeamId: OpaqueTeamId(json['homeTeamId']! as String),
      awayTeamId: OpaqueTeamId(json['awayTeamId']! as String),
    );
  }
}

/// Expected score for grading a participant response.
class ExpectedScore {
  const ExpectedScore({
    required this.fact,
  });

  final ScoreFact fact;
}

/// Pure grading: correct goals with wrong team attribution is incorrect.
ScoreAnswerVerdict gradeScoreAnswer({
  required ExpectedScore expected,
  required ScoreFact answer,
}) {
  final goalsMatch = expected.fact.homeGoals == answer.homeGoals &&
      expected.fact.awayGoals == answer.awayGoals;
  final teamsMatch = expected.fact.homeTeamId == answer.homeTeamId &&
      expected.fact.awayTeamId == answer.awayTeamId;

  if (goalsMatch && teamsMatch) {
    return ScoreAnswerVerdict.correct;
  }
  if (goalsMatch && !teamsMatch) {
    return ScoreAnswerVerdict.wrongTeamAttribution;
  }
  return ScoreAnswerVerdict.incorrectGoals;
}

enum ScoreAnswerVerdict {
  correct,
  wrongTeamAttribution,
  incorrectGoals,
}
