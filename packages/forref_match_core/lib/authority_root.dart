/// Generation-1 MAIN_REFEREE capture root with no predecessor. No transfer API.
final class GenerationOneAuthorityRoot {
  const GenerationOneAuthorityRoot({
    required this.matchId,
    required this.principalId,
    required this.deviceId,
  })  : generation = 1,
        predecessorAbsent = true;

  final String matchId;
  final String principalId;
  final String deviceId;
  final int generation;
  final bool predecessorAbsent;

  @override
  bool operator ==(Object other) =>
      other is GenerationOneAuthorityRoot &&
      matchId == other.matchId &&
      principalId == other.principalId &&
      deviceId == other.deviceId &&
      generation == other.generation &&
      predecessorAbsent == other.predecessorAbsent;

  @override
  int get hashCode =>
      Object.hash(matchId, principalId, deviceId, generation, predecessorAbsent);
}
