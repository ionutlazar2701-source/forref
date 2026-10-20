import '../match_team.dart';

/// Derived score state. Numeric values exist only on [KnownScore].
sealed class ScoreProjection {
  const ScoreProjection();
}

/// Positive proof produced a deterministic score keyed by [MatchTeamId].
final class KnownScore extends ScoreProjection {
  KnownScore(Map<MatchTeamId, int> goalsByTeam)
      : goalsByTeam = Map.unmodifiable(
          Map<MatchTeamId, int>.from(goalsByTeam),
        );

  final Map<MatchTeamId, int> goalsByTeam;

  @override
  bool operator ==(Object other) {
    if (other is! KnownScore) return false;
    if (goalsByTeam.length != other.goalsByTeam.length) return false;
    for (final entry in goalsByTeam.entries) {
      if (other.goalsByTeam[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
        goalsByTeam.entries.map((e) => Object.hash(e.key, e.value)),
      );
}

/// Score cannot be read as a numeral (empty history, gaps, missing proof, etc.).
final class ScoreUnavailable extends ScoreProjection {
  const ScoreUnavailable();

  @override
  bool operator ==(Object other) => other is ScoreUnavailable;

  @override
  int get hashCode => 1;
}

/// Contradictory complete branches — no trusted numeral.
final class ScoreConflicted extends ScoreProjection {
  const ScoreConflicted();

  @override
  bool operator ==(Object other) => other is ScoreConflicted;

  @override
  int get hashCode => 2;
}
