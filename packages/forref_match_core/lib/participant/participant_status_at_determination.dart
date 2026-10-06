/// Historical participant status at the time of a future sporting determination.
///
/// Does not define participant identity. The same [MatchParticipantId] may
/// appear under different statuses across determinations.
enum ParticipantStatusAtDetermination {
  onFieldPlayer,
  substitute,
  substitutedPlayer,
  teamOfficial,
  seniorCoachPresent,
}

extension ParticipantStatusAtDeterminationWire
    on ParticipantStatusAtDetermination {
  String get wireValue => switch (this) {
        ParticipantStatusAtDetermination.onFieldPlayer => 'ON_FIELD_PLAYER',
        ParticipantStatusAtDetermination.substitute => 'SUBSTITUTE',
        ParticipantStatusAtDetermination.substitutedPlayer =>
          'SUBSTITUTED_PLAYER',
        ParticipantStatusAtDetermination.teamOfficial => 'TEAM_OFFICIAL',
        ParticipantStatusAtDetermination.seniorCoachPresent =>
          'SENIOR_COACH_PRESENT',
      };

  static ParticipantStatusAtDetermination? parseWire(String value) =>
      switch (value) {
        'ON_FIELD_PLAYER' => ParticipantStatusAtDetermination.onFieldPlayer,
        'SUBSTITUTE' => ParticipantStatusAtDetermination.substitute,
        'SUBSTITUTED_PLAYER' =>
          ParticipantStatusAtDetermination.substitutedPlayer,
        'TEAM_OFFICIAL' => ParticipantStatusAtDetermination.teamOfficial,
        'SENIOR_COACH_PRESENT' =>
          ParticipantStatusAtDetermination.seniorCoachPresent,
        _ => null,
      };
}
