import 'package:match_core/match_core.dart';

/// Version of [MatchConfigurationPayload].
///
/// This is a phone-local projection of configuration already stored on the
/// legacy match document. It is not a Match Record, not a commit
/// acknowledgement, and not a watch or cloud transport.
const int matchConfigurationPayloadVersion = 1;

/// Configuration a later watch gate may read. Version 1 carries no sync.
final class MatchConfigurationPayload {
  const MatchConfigurationPayload({
    required this.payloadVersion,
    required this.matchId,
    required this.updatedAt,
    required this.date,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.halfDurationSeconds,
    required this.extraTimeEnabled,
    required this.extraTimeHalfDurationSeconds,
    this.competition,
    this.venue,
    this.homeTeamName,
    this.awayTeamName,
    this.referee,
    this.assistantReferee1,
    this.assistantReferee2,
    this.fourthOfficial,
  });

  factory MatchConfigurationPayload.fromMatch(Match match) {
    return MatchConfigurationPayload(
      payloadVersion: matchConfigurationPayloadVersion,
      matchId: match.matchId,
      updatedAt: match.updatedAt.toUtc(),
      date: match.date,
      competition: _blankToNull(match.competition),
      venue: _blankToNull(match.venue),
      homeTeamId: match.teams.home.teamId,
      homeTeamName: _blankToNull(match.teams.home.name),
      awayTeamId: match.teams.away.teamId,
      awayTeamName: _blankToNull(match.teams.away.name),
      halfDurationSeconds: match.settings.halfDurationSeconds,
      extraTimeEnabled: match.settings.extraTimeEnabled,
      extraTimeHalfDurationSeconds: match.settings.extraTimeHalfDurationSeconds,
      referee: _blankToNull(match.crew.referee?.name),
      assistantReferee1: _blankToNull(match.crew.assistant1?.name),
      assistantReferee2: _blankToNull(match.crew.assistant2?.name),
      fourthOfficial: _blankToNull(match.crew.fourthOfficial?.name),
    );
  }

  factory MatchConfigurationPayload.fromJson(Map<String, Object?> json) {
    final version = json['payloadVersion'];
    if (version != matchConfigurationPayloadVersion) {
      throw FormatException(
        'Unsupported match configuration payload version: $version',
      );
    }
    return MatchConfigurationPayload(
      payloadVersion: version as int,
      matchId: json['matchId'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      date: json['date'] as String,
      competition: json['competition'] as String?,
      venue: json['venue'] as String?,
      homeTeamId: json['homeTeamId'] as String,
      homeTeamName: json['homeTeamName'] as String?,
      awayTeamId: json['awayTeamId'] as String,
      awayTeamName: json['awayTeamName'] as String?,
      halfDurationSeconds: json['halfDurationSeconds'] as int,
      extraTimeEnabled: json['extraTimeEnabled'] as bool,
      extraTimeHalfDurationSeconds: json['extraTimeHalfDurationSeconds'] as int,
      referee: json['referee'] as String?,
      assistantReferee1: json['assistantReferee1'] as String?,
      assistantReferee2: json['assistantReferee2'] as String?,
      fourthOfficial: json['fourthOfficial'] as String?,
    );
  }

  final int payloadVersion;
  final String matchId;
  final DateTime updatedAt;
  final String date;
  final String? competition;
  final String? venue;
  final String homeTeamId;
  final String? homeTeamName;
  final String awayTeamId;
  final String? awayTeamName;
  final int halfDurationSeconds;
  final bool extraTimeEnabled;
  final int extraTimeHalfDurationSeconds;
  final String? referee;
  final String? assistantReferee1;
  final String? assistantReferee2;
  final String? fourthOfficial;

  Map<String, Object?> toJson() {
    return {
      'payloadVersion': payloadVersion,
      'matchId': matchId,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'date': date,
      'competition': competition,
      'venue': venue,
      'homeTeamId': homeTeamId,
      'homeTeamName': homeTeamName,
      'awayTeamId': awayTeamId,
      'awayTeamName': awayTeamName,
      'halfDurationSeconds': halfDurationSeconds,
      'extraTimeEnabled': extraTimeEnabled,
      'extraTimeHalfDurationSeconds': extraTimeHalfDurationSeconds,
      'referee': referee,
      'assistantReferee1': assistantReferee1,
      'assistantReferee2': assistantReferee2,
      'fourthOfficial': fourthOfficial,
    };
  }
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
