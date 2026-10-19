import 'match_team.dart';

/// Opaque stable participant token.
///
/// Match scope lives on [MatchScopedParticipantId]. Shirt number, display
/// name, and [ParticipantSituation] are not this value.
final class MatchParticipantId {
  MatchParticipantId(String raw) : value = _validate(raw);

  final String value;

  static String _validate(String raw) {
    if (raw.isEmpty) {
      throw ArgumentError.value(raw, 'raw', 'MatchParticipantId cannot be empty');
    }
    return raw;
  }

  /// Deterministic wire form. The same characters round-trip to the same id.
  String get wireValue => value;

  static MatchParticipantId parseWire(String wire) => MatchParticipantId(wire);

  @override
  bool operator ==(Object other) =>
      other is MatchParticipantId && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'MatchParticipantId($value)';
}

/// Match-scoped participant identity.
///
/// The same token in two matches is two identities. There is no merge API.
final class MatchScopedParticipantId {
  MatchScopedParticipantId({
    required String matchId,
    required this.participantId,
  }) : matchId = _nonEmpty(matchId);

  final String matchId;
  final MatchParticipantId participantId;

  static String _nonEmpty(String raw) {
    if (raw.isEmpty) {
      throw ArgumentError.value(raw, 'matchId', 'match id cannot be empty');
    }
    return raw;
  }

  Map<String, String> toJson() => {
        'matchId': matchId,
        'participantId': participantId.wireValue,
      };

  static MatchScopedParticipantId fromJson(Map<String, String> json) {
    final matchId = json['matchId'];
    final participantId = json['participantId'];
    if (matchId == null || participantId == null) {
      throw ArgumentError.value(json, 'json', 'match-scoped identity is incomplete');
    }
    return MatchScopedParticipantId(
      matchId: matchId,
      participantId: MatchParticipantId.parseWire(participantId),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MatchScopedParticipantId &&
      matchId == other.matchId &&
      participantId == other.participantId;

  @override
  int get hashCode => Object.hash(matchId, participantId);
}

/// Smallest team association. Not a roster and not a status.
final class MatchParticipantTeamBinding {
  const MatchParticipantTeamBinding({
    required this.matchId,
    required this.participantId,
    required this.teamId,
  });

  final String matchId;
  final MatchParticipantId participantId;
  final MatchTeamId teamId;

  @override
  bool operator ==(Object other) =>
      other is MatchParticipantTeamBinding &&
      matchId == other.matchId &&
      participantId == other.participantId &&
      teamId == other.teamId;

  @override
  int get hashCode => Object.hash(matchId, participantId, teamId);
}

/// Historical situation. It is not part of [MatchParticipantId].
enum ParticipantSituation {
  onField,
  temporarilyOffField,
  substitute,
  substituted,
}
