import '../enums/enums.dart';

/// Squad or event player reference. See docs/data-model.md.
final class PlayerRef {
  const PlayerRef({
    this.playerId,
    this.shirtNumber,
    this.name,
    required this.isUnknown,
  });

  final String? playerId;
  final int? shirtNumber;
  final String? name;
  final bool isUnknown;
}

final class Player {
  const Player({
    required this.playerId,
    this.shirtNumber,
    this.name,
    this.role,
  });

  final String playerId;
  final int? shirtNumber;
  final String? name;
  final PlayerRole? role;
}
