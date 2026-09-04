import '../enums/enums.dart';
import 'crew.dart';
import 'event.dart';
import 'history_entry.dart';
import 'match_state.dart';
import 'period.dart';
import 'player.dart';
import 'team.dart';

final class MatchSettings {
  const MatchSettings({
    required this.halfDurationSeconds,
    this.extraTimeEnabled = false,
    this.extraTimeHalfDurationSeconds = 900,
  });

  final int halfDurationSeconds;
  final bool extraTimeEnabled;
  final int extraTimeHalfDurationSeconds;

  MatchSettings copyWith({
    int? halfDurationSeconds,
    bool? extraTimeEnabled,
    int? extraTimeHalfDurationSeconds,
  }) {
    return MatchSettings(
      halfDurationSeconds:
          halfDurationSeconds ?? this.halfDurationSeconds,
      extraTimeEnabled: extraTimeEnabled ?? this.extraTimeEnabled,
      extraTimeHalfDurationSeconds: extraTimeHalfDurationSeconds ??
          this.extraTimeHalfDurationSeconds,
    );
  }
}

final class TeamSquad {
  const TeamSquad({this.players = const []});

  final List<Player> players;
}

final class Squads {
  const Squads({
    this.home = const TeamSquad(),
    this.away = const TeamSquad(),
  });

  final TeamSquad home;
  final TeamSquad away;
}

final class SyncMeta {
  const SyncMeta({
    required this.syncState,
    this.lastSyncedAt,
  });

  final SyncState syncState;
  final DateTime? lastSyncedAt;
}

/// Canonical Match aggregate. Fields only — no engine logic.
final class Match {
  const Match({
    this.schemaVersion = 1,
    required this.matchId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.competition,
    this.venue,
    required this.date,
    required this.teams,
    this.crew = const Crew(),
    required this.settings,
    this.squads = const Squads(),
    this.periods = const [],
    required this.currentState,
    required this.score,
    this.events = const [],
    this.history = const [],
    this.sync = const SyncMeta(syncState: SyncState.localOnly),
  });

  final int schemaVersion;
  final String matchId;
  final MatchStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? competition;
  final String? venue;
  final String date;
  final Teams teams;
  final Crew crew;
  final MatchSettings settings;
  final Squads squads;
  final List<Period> periods;
  final MatchState currentState;
  final Score score;
  final List<MatchEvent> events;
  final List<HistoryEntry> history;
  final SyncMeta sync;

  Match copyWith({
    MatchStatus? status,
    DateTime? updatedAt,
    String? competition,
    bool clearCompetition = false,
    String? venue,
    bool clearVenue = false,
    String? date,
    Teams? teams,
    Crew? crew,
    MatchSettings? settings,
    Squads? squads,
    List<Period>? periods,
    MatchState? currentState,
    Score? score,
    List<MatchEvent>? events,
    List<HistoryEntry>? history,
  }) {
    return Match(
      schemaVersion: schemaVersion,
      matchId: matchId,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      competition:
          clearCompetition ? null : (competition ?? this.competition),
      venue: clearVenue ? null : (venue ?? this.venue),
      date: date ?? this.date,
      teams: teams ?? this.teams,
      crew: crew ?? this.crew,
      settings: settings ?? this.settings,
      squads: squads ?? this.squads,
      periods: periods ?? this.periods,
      currentState: currentState ?? this.currentState,
      score: score ?? this.score,
      events: events ?? this.events,
      history: history ?? this.history,
      sync: sync,
    );
  }
}
