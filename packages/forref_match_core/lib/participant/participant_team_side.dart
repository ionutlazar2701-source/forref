/// Team side for participant identity. Distinct from goal crediting semantics.
enum ParticipantTeamSide {
  home,
  away,
}

extension ParticipantTeamSideWire on ParticipantTeamSide {
  String get wireValue => switch (this) {
        ParticipantTeamSide.home => 'HOME',
        ParticipantTeamSide.away => 'AWAY',
      };

  static ParticipantTeamSide? parseWire(String value) => switch (value) {
        'HOME' => ParticipantTeamSide.home,
        'AWAY' => ParticipantTeamSide.away,
        _ => null,
      };
}
