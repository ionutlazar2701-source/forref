final class CrewMember {
  const CrewMember({this.name});

  final String? name;
}

final class Crew {
  const Crew({
    this.referee,
    this.assistant1,
    this.assistant2,
    this.fourthOfficial,
  });

  final CrewMember? referee;
  final CrewMember? assistant1;
  final CrewMember? assistant2;
  final CrewMember? fourthOfficial;
}
