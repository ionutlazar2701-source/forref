import 'package:match_core/match_core.dart';
import 'package:referee_phone/l10n/app_localizations.dart';

String teamLabel(Match match, String teamId, AppLocalizations l10n) {
  if (teamId == match.teams.home.teamId) {
    return _nameOr(match.teams.home.name, l10n.homeFallback);
  }
  if (teamId == match.teams.away.teamId) {
    return _nameOr(match.teams.away.name, l10n.awayFallback);
  }
  return teamId;
}

String homeLabel(Match match, AppLocalizations l10n) =>
    _nameOr(match.teams.home.name, l10n.homeFallback);

String awayLabel(Match match, AppLocalizations l10n) =>
    _nameOr(match.teams.away.name, l10n.awayFallback);

String matchStatusLabel(Match match, AppLocalizations l10n) {
  final extra = match.currentState.periodId == PeriodId.extraTime1 ||
      match.currentState.periodId == PeriodId.extraTime2;
  if (extra &&
      (match.status == MatchStatus.live ||
          match.status == MatchStatus.paused)) {
    return l10n.statusExtraTime;
  }
  return switch (match.status) {
    MatchStatus.setup => l10n.statusSetup,
    MatchStatus.ready => l10n.statusReady,
    MatchStatus.live => l10n.statusLive,
    MatchStatus.paused => l10n.statusPaused,
    MatchStatus.halfTime => l10n.statusHalfTime,
    MatchStatus.fullTime => l10n.statusFullTime,
    MatchStatus.completed => l10n.statusCompleted,
  };
}

String periodLabel(PeriodId id, AppLocalizations l10n) {
  return switch (id) {
    PeriodId.firstHalf => l10n.period1h,
    PeriodId.secondHalf => l10n.period2h,
    PeriodId.extraTime1 => l10n.periodEt1,
    PeriodId.extraTime2 => l10n.periodEt2,
    PeriodId.penalties => l10n.periodEt2,
  };
}

String eventTypeLabel(EventType type, AppLocalizations l10n) {
  return switch (type) {
    EventType.goal => l10n.goal,
    EventType.yellowCard => l10n.yellow,
    EventType.redCard => l10n.red,
    EventType.substitution => l10n.sub,
    EventType.injury => l10n.injury,
  };
}

String _nameOr(String? name, String fallback) {
  final trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty) return fallback;
  return trimmed;
}
