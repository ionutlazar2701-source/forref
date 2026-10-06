import 'dart:math';

/// Opaque match-scoped canonical participant identity.
///
/// Stable across status changes for the same real person. Not a shirt number,
/// roster index, UI object id, or projection artifact.
final class MatchParticipantId {
  MatchParticipantId(this.value) : assert(value.isNotEmpty);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is MatchParticipantId && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'MatchParticipantId($value)';
}

/// Produces collision-resistant [MatchParticipantId] values.
abstract interface class MatchParticipantIdGenerator {
  MatchParticipantId newParticipantId();
}

/// Secure-random participant id generator for tests and composition roots.
final class SecureMatchParticipantIdGenerator
    implements MatchParticipantIdGenerator {
  const SecureMatchParticipantIdGenerator();

  static final _random = Random.secure();

  @override
  MatchParticipantId newParticipantId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return MatchParticipantId('mpid-$hex');
  }
}
