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
