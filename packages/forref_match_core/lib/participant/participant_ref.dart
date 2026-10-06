import 'match_participant_id.dart';
import 'participant_binding.dart';
import 'participant_team_side.dart';

/// Typed participant reference for future authoritative sporting records.
final class ParticipantRef {
  const ParticipantRef({
    required this.matchParticipantId,
    required this.teamSide,
    required this.binding,
  });

  final MatchParticipantId matchParticipantId;
  final ParticipantTeamSide teamSide;
  final ParticipantBinding binding;

  ParticipantBindingContext get bindingContext => ParticipantBindingContext(
        teamSide: teamSide,
        binding: binding,
      );

  @override
  bool operator ==(Object other) =>
      other is ParticipantRef &&
      matchParticipantId == other.matchParticipantId &&
      teamSide == other.teamSide &&
      binding == other.binding;

  @override
  int get hashCode => Object.hash(matchParticipantId, teamSide, binding);
}

/// Wire encoding for durable [ParticipantRef] round-trip.
abstract final class ParticipantRefWire {
  static Map<String, Object?> encode(ParticipantRef ref) {
    return {
      'matchParticipantId': ref.matchParticipantId.value,
      'teamSide': ref.teamSide.wireValue,
      'binding': ParticipantBindingWire.encode(ref.binding),
    };
  }

  static ParticipantRef decode(Map<String, Object?> json) {
    final participantId = json['matchParticipantId'];
    if (participantId is! String || participantId.isEmpty) {
      throw FormatException('ParticipantRef matchParticipantId is required');
    }
    final teamSide = ParticipantTeamSideWire.parseWire(
      _requiredString(json['teamSide'], 'teamSide'),
    );
    if (teamSide == null) {
      throw FormatException('ParticipantRef teamSide is invalid');
    }
    final bindingRaw = json['binding'];
    if (bindingRaw is! Map) {
      throw FormatException('ParticipantRef binding is missing');
    }
    return ParticipantRef(
      matchParticipantId: MatchParticipantId(participantId),
      teamSide: teamSide,
      binding: ParticipantBindingWire.decode(_stringKeyMap(bindingRaw)),
    );
  }

  static String _requiredString(Object? value, String label) {
    if (value is! String || value.isEmpty) {
      throw FormatException('ParticipantRef $label is invalid');
    }
    return value;
  }

  static Map<String, Object?> _stringKeyMap(Map<Object?, Object?> value) {
    return {
      for (final entry in value.entries) entry.key as String: entry.value,
    };
  }
}
