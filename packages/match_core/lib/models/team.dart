final class Team {
  const Team({
    required this.teamId,
    this.name,
  });

  final String teamId;
  final String? name;

  Team copyWith({String? name, bool clearName = false}) {
    return Team(
      teamId: teamId,
      name: clearName ? null : (name ?? this.name),
    );
  }
}

final class Teams {
  const Teams({
    required this.home,
    required this.away,
  });

  final Team home;
  final Team away;
}
