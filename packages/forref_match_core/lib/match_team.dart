/// Opaque stable team identity for a match. Not HOME, AWAY, display slot, or name.
final class MatchTeamId {
  MatchTeamId(String raw) : value = _validate(raw);

  final String value;

  static String _validate(String raw) {
    if (raw.isEmpty) {
      throw ArgumentError.value(raw, 'raw', 'MatchTeamId cannot be empty');
    }
    final upper = raw.toUpperCase();
    if (upper == 'HOME' || upper == 'AWAY') {
      throw ArgumentError.value(raw, 'raw', 'MatchTeamId cannot be HOME or AWAY');
    }
    return raw;
  }

  @override
  bool operator ==(Object other) =>
      other is MatchTeamId && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'MatchTeamId($value)';
}

/// Match-scoped binding of one [MatchTeamId]. No roster or player identity.
final class MatchTeamBinding {
  const MatchTeamBinding({
    required this.matchId,
    required this.teamId,
  });

  final String matchId;
  final MatchTeamId teamId;

  @override
  bool operator ==(Object other) =>
      other is MatchTeamBinding &&
      matchId == other.matchId &&
      teamId == other.teamId;

  @override
  int get hashCode => Object.hash(matchId, teamId);
}
