import 'package:forref_match_core/forref_match_core.dart';
import 'package:referee_phone/l10n/app_localizations.dart';
import 'package:referee_phone/match/new_match.dart';

/// UI clock text for one projected goal.
///
/// Exact continuity uses derived playing time. Bounded continuity uses the
/// same range treatment as the live clock. Unresolved continuity does not
/// invent a minute and does not fall back to 00:00.
String formatProjectedGoalTime(
  ProjectedGoalTemporal temporal,
  AppLocalizations l10n,
) {
  if (temporal.continuity == TemporalContinuityStatus.exactContinuity &&
      temporal.exactPlayingTime != null) {
    return formatMatchClock(temporal.exactPlayingTime!.inSeconds);
  }
  if (temporal.continuity == TemporalContinuityStatus.boundedContinuity &&
      temporal.playingTimeLowerBound != null &&
      temporal.playingTimeUpperBound != null) {
    return '${formatMatchClock(temporal.playingTimeLowerBound!.inSeconds)}–'
        '${formatMatchClock(temporal.playingTimeUpperBound!.inSeconds)}';
  }
  return l10n.elapsedUnavailable;
}
