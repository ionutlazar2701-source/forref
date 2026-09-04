import '../enums/enums.dart';
import '../models/crew.dart';
import '../models/event.dart';
import '../models/history_entry.dart';
import '../models/match.dart';
import '../models/match_state.dart';
import '../models/period.dart';
import '../models/player.dart';
import '../models/team.dart';

/// Canonical JSON. Example: docs/examples/match-canonical.json.
final class MatchJson {
  const MatchJson();

  Map<String, Object?> toJson(Match match) {
    return {
      'schemaVersion': match.schemaVersion,
      'matchId': match.matchId,
      'status': match.status.jsonValue,
      'createdAt': _iso(match.createdAt),
      'updatedAt': _iso(match.updatedAt),
      'competition': match.competition,
      'venue': match.venue,
      'date': match.date,
      'teams': {
        'home': _team(match.teams.home),
        'away': _team(match.teams.away),
      },
      'crew': {
        'referee': _crewMember(match.crew.referee),
        'assistant1': _crewMember(match.crew.assistant1),
        'assistant2': _crewMember(match.crew.assistant2),
        'fourthOfficial': _crewMember(match.crew.fourthOfficial),
      },
      'settings': {
        'halfDurationSeconds': match.settings.halfDurationSeconds,
        'extraTimeEnabled': match.settings.extraTimeEnabled,
        'extraTimeHalfDurationSeconds':
            match.settings.extraTimeHalfDurationSeconds,
      },
      'squads': {
        'home': _squad(match.squads.home),
        'away': _squad(match.squads.away),
      },
      'periods': [for (final p in match.periods) _period(p)],
      'currentState': currentStateToJson(match.currentState),
      'score': {
        'home': match.score.home,
        'away': match.score.away,
      },
      'events': [for (final e in match.events) eventToJson(e)],
      'history': [for (final h in match.history) _history(h)],
      'sync': {
        'syncState': match.sync.syncState.jsonValue,
        'lastSyncedAt': _isoOrNull(match.sync.lastSyncedAt),
      },
    };
  }

  Match fromJson(Map json) {
    final teams = json['teams'] as Map;
    final crew = json['crew'] as Map;
    final settings = json['settings'] as Map;
    final squads = json['squads'] as Map;
    final state = json['currentState'] as Map;
    final score = json['score'] as Map;
    final homeSquad = squads['home'] as Map;
    final awaySquad = squads['away'] as Map;

    return Match(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      matchId: json['matchId'] as String,
      status: _enum(MatchStatus.values, json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      competition: json['competition'] as String?,
      venue: json['venue'] as String?,
      date: json['date'] as String,
      teams: Teams(
        home: _teamFrom(teams['home'] as Map),
        away: _teamFrom(teams['away'] as Map),
      ),
      crew: Crew(
        referee: _crewFrom(crew['referee']),
        assistant1: _crewFrom(crew['assistant1']),
        assistant2: _crewFrom(crew['assistant2']),
        fourthOfficial: _crewFrom(crew['fourthOfficial']),
      ),
      settings: MatchSettings(
        halfDurationSeconds: settings['halfDurationSeconds'] as int,
        extraTimeEnabled: settings['extraTimeEnabled'] as bool? ?? false,
        extraTimeHalfDurationSeconds:
            settings['extraTimeHalfDurationSeconds'] as int? ?? 900,
      ),
      squads: Squads(
        home: TeamSquad(
          players: [
            for (final p in homeSquad['players'] as List)
              _playerFrom(p as Map),
          ],
        ),
        away: TeamSquad(
          players: [
            for (final p in awaySquad['players'] as List)
              _playerFrom(p as Map),
          ],
        ),
      ),
      periods: [
        for (final p in json['periods'] as List) _periodFrom(p as Map),
      ],
      currentState: currentStateFromJson(state),
      score: Score(
        home: score['home'] as int,
        away: score['away'] as int,
      ),
      events: [
        for (final e in json['events'] as List) _eventFrom(e as Map),
      ],
      history: [
        for (final h in json['history'] as List) _historyFrom(h as Map),
      ],
      sync: SyncMeta(
        syncState: _enum(
          SyncState.values,
          (json['sync'] as Map)['syncState'] as String,
        ),
        lastSyncedAt: _parseTime((json['sync'] as Map)['lastSyncedAt']),
      ),
    );
  }

  Map<String, Object?> _team(Team team) => {
        'teamId': team.teamId,
        'name': team.name,
      };

  Team _teamFrom(Map json) => Team(
        teamId: json['teamId'] as String,
        name: json['name'] as String?,
      );

  Map<String, Object?>? _crewMember(CrewMember? member) {
    if (member == null) return null;
    return {'name': member.name};
  }

  CrewMember? _crewFrom(Object? json) {
    if (json == null) return null;
    final map = json as Map;
    return CrewMember(name: map['name'] as String?);
  }

  Map<String, Object?> _squad(TeamSquad squad) => {
        'players': [
          for (final p in squad.players)
            {
              'playerId': p.playerId,
              'shirtNumber': p.shirtNumber,
              'name': p.name,
              'role': p.role?.jsonValue,
            },
        ],
      };

  Player _playerFrom(Map json) => Player(
        playerId: json['playerId'] as String,
        shirtNumber: json['shirtNumber'] as int?,
        name: json['name'] as String?,
        role: json['role'] == null
            ? null
            : _enum(PlayerRole.values, json['role'] as String),
      );

  Map<String, Object?> _period(Period period) => {
        'id': period.id.jsonValue,
        'status': period.status.jsonValue,
        'startedAt': _isoOrNull(period.startedAt),
        'endedAt': _isoOrNull(period.endedAt),
        'addedTimeSeconds': period.addedTimeSeconds,
      };

  Period _periodFrom(Map json) => Period(
        id: _enum(PeriodId.values, json['id'] as String),
        status: _enum(PeriodStatus.values, json['status'] as String),
        startedAt: _parseTime(json['startedAt']),
        endedAt: _parseTime(json['endedAt']),
        addedTimeSeconds: json['addedTimeSeconds'] as int? ?? 0,
      );

  Map<String, Object?> currentStateToJson(MatchState state) => {
        'periodId': state.periodId.jsonValue,
        'clockRunning': state.clockRunning,
        'elapsedSeconds': state.elapsedSeconds,
        'runningSince': _isoOrNull(state.runningSince),
        'addedTimeSeconds': state.addedTimeSeconds,
      };

  MatchState currentStateFromJson(Map json) => MatchState(
        periodId: _enum(PeriodId.values, json['periodId'] as String),
        clockRunning: json['clockRunning'] as bool,
        elapsedSeconds: json['elapsedSeconds'] as int,
        runningSince: _parseTime(json['runningSince']),
        addedTimeSeconds: json['addedTimeSeconds'] as int? ?? 0,
      );

  /// Status + periods + clock cache. Used for Full time Undo.
  Map<String, Object?> clockFieldsToJson(Match match) => {
        'status': match.status.jsonValue,
        'periods': [for (final p in match.periods) _period(p)],
        'currentState': currentStateToJson(match.currentState),
      };

  Match applyClockFields(Match match, Map json) {
    return match.copyWith(
      status: _enum(MatchStatus.values, json['status'] as String),
      periods: [
        for (final p in json['periods'] as List) _periodFrom(p as Map),
      ],
      currentState: currentStateFromJson(json['currentState'] as Map),
    );
  }

  Map<String, Object?> eventToJson(MatchEvent event) => _event(event);

  MatchEvent eventFromJson(Map json) => _eventFrom(json);

  Map<String, Object?> historyToJson(HistoryEntry entry) => _history(entry);

  HistoryEntry historyFromJson(Map json) => _historyFrom(json);

  /// Match document without events/history (those are separate rows).
  Map<String, Object?> documentToJson(Match match) {
    final json = toJson(match);
    json['events'] = const <Object?>[];
    json['history'] = const <Object?>[];
    return json;
  }

  Map<String, Object?> _event(MatchEvent event) => {
        'eventId': event.eventId,
        'matchId': event.matchId,
        'type': event.type.jsonValue,
        'status': event.status.jsonValue,
        'periodId': event.periodId.jsonValue,
        'matchTime': event.matchTime,
        'createdAt': _iso(event.createdAt),
        'updatedAt': _iso(event.updatedAt),
        'data': _eventData(event.type, event.data),
      };

  MatchEvent _eventFrom(Map json) {
    final type = _enum(EventType.values, json['type'] as String);
    return MatchEvent(
      eventId: json['eventId'] as String,
      matchId: json['matchId'] as String,
      type: type,
      status: _enum(EventStatus.values, json['status'] as String),
      periodId: _enum(PeriodId.values, json['periodId'] as String),
      matchTime: json['matchTime'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      data: _eventDataFrom(type, json['data'] as Map),
    );
  }

  Map<String, Object?> _eventData(EventType type, EventData data) {
    switch (type) {
      case EventType.goal:
        return {
          'teamId': data.teamId,
          'player': _playerRef(data.player),
          'isOwnGoal': data.isOwnGoal ?? false,
          'note': data.note,
          'reason': data.reason,
        };
      case EventType.yellowCard:
      case EventType.redCard:
      case EventType.injury:
        return {
          'teamId': data.teamId,
          'player': _playerRef(data.player),
          'note': data.note,
          'reason': data.reason,
        };
      case EventType.substitution:
        return {
          'teamId': data.teamId,
          'out': _playerRef(data.out),
          'in': _playerRef(data.inPlayer),
          'note': data.note,
          'reason': data.reason,
        };
    }
  }

  EventData _eventDataFrom(EventType type, Map json) {
    switch (type) {
      case EventType.goal:
        return EventData(
          teamId: json['teamId'] as String?,
          player: _playerRefFrom(json['player'] as Map?),
          isOwnGoal: json['isOwnGoal'] as bool? ?? false,
          note: json['note'] as String?,
          reason: json['reason'] as String?,
        );
      case EventType.yellowCard:
      case EventType.redCard:
      case EventType.injury:
        return EventData(
          teamId: json['teamId'] as String?,
          player: _playerRefFrom(json['player'] as Map?),
          note: json['note'] as String?,
          reason: json['reason'] as String?,
        );
      case EventType.substitution:
        return EventData(
          teamId: json['teamId'] as String?,
          out: _playerRefFrom(json['out'] as Map?),
          inPlayer: _playerRefFrom(json['in'] as Map?),
          note: json['note'] as String?,
          reason: json['reason'] as String?,
        );
    }
  }

  Map<String, Object?> _playerRef(PlayerRef? ref) {
    final value = ref ?? const PlayerRef(isUnknown: true);
    return {
      'playerId': value.playerId,
      'shirtNumber': value.shirtNumber,
      'name': value.name,
      'isUnknown': value.isUnknown,
    };
  }

  PlayerRef? _playerRefFrom(Map? json) {
    if (json == null) return null;
    return PlayerRef(
      playerId: json['playerId'] as String?,
      shirtNumber: json['shirtNumber'] as int?,
      name: json['name'] as String?,
      isUnknown: json['isUnknown'] as bool? ?? false,
    );
  }

  Map<String, Object?> _history(HistoryEntry entry) => {
        'historyId': entry.historyId,
        'eventId': entry.eventId,
        'action': entry.action.jsonValue,
        'changedAt': _iso(entry.changedAt),
        'previousValue': entry.previousValue,
        'newValue': entry.newValue,
      };

  HistoryEntry _historyFrom(Map json) => HistoryEntry(
        historyId: json['historyId'] as String,
        eventId: json['eventId'] as String?,
        action: _enum(HistoryAction.values, json['action'] as String),
        changedAt: DateTime.parse(json['changedAt'] as String).toUtc(),
        previousValue: Map<String, Object?>.from(json['previousValue'] as Map),
        newValue: Map<String, Object?>.from(json['newValue'] as Map),
      );

  String _iso(DateTime time) => time.toUtc().toIso8601String();

  String? _isoOrNull(DateTime? time) =>
      time == null ? null : time.toUtc().toIso8601String();

  DateTime? _parseTime(Object? value) {
    if (value == null) return null;
    return DateTime.parse(value as String).toUtc();
  }

  T _enum<T extends Enum>(List<T> values, String jsonValue) {
    for (final value in values) {
      final encoded = (value as dynamic).jsonValue as String;
      if (encoded == jsonValue) return value;
    }
    throw FormatException('Unknown $T: $jsonValue');
  }
}
