import '../enums/enums.dart';
import '../models/event.dart';

/// Rebuilds [Score] from current goal events. Own goal: [EventData.teamId]
/// is the conceding team; the other side gets the point.
final class ScoreCalculator {
  const ScoreCalculator();

  Score fromEvents(
    List<MatchEvent> events, {
    required String homeTeamId,
    required String awayTeamId,
  }) {
    var home = 0;
    var away = 0;
    for (final event in events) {
      if (event.type != EventType.goal) continue;
      final teamId = event.data.teamId;
      if (teamId == null) continue;
      final ownGoal = event.data.isOwnGoal ?? false;
      if (ownGoal) {
        if (teamId == homeTeamId) {
          away++;
        } else if (teamId == awayTeamId) {
          home++;
        }
      } else {
        if (teamId == homeTeamId) {
          home++;
        } else if (teamId == awayTeamId) {
          away++;
        }
      }
    }
    return Score(home: home, away: away);
  }
}
