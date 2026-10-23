import '../match_participant.dart';
import '../match_team.dart';
import '../semantics/v1_semantic_payload.dart';

/// Trusted participant-team evidence used only to admit a completed substitution.
sealed class ParticipantTeamBindingAssessment {
  const ParticipantTeamBindingAssessment();
}

final class TrustedParticipantTeamBinding
    extends ParticipantTeamBindingAssessment {
  const TrustedParticipantTeamBinding(this.binding);

  final MatchParticipantTeamBinding binding;
}

final class MissingParticipantTeamBinding
    extends ParticipantTeamBindingAssessment {
  const MissingParticipantTeamBinding();
}

final class AmbiguousParticipantTeamBinding
    extends ParticipantTeamBindingAssessment {
  const AmbiguousParticipantTeamBinding();
}

ParticipantTeamBindingAssessment assessParticipantTeamBinding({
  required String matchId,
  required MatchParticipantId participantId,
  required List<MatchParticipantTeamBinding> bindings,
}) {
  final teams = <MatchTeamId>{};
  MatchParticipantTeamBinding? chosen;
  for (final binding in bindings) {
    if (binding.matchId != matchId || binding.participantId != participantId) {
      continue;
    }
    teams.add(binding.teamId);
    chosen ??= binding;
  }
  if (teams.isEmpty) return const MissingParticipantTeamBinding();
  if (teams.length != 1) return const AmbiguousParticipantTeamBinding();
  return TrustedParticipantTeamBinding(chosen!);
}

sealed class SubstitutionAdmission {
  const SubstitutionAdmission();
}

final class SubstitutionAdmitted extends SubstitutionAdmission {
  const SubstitutionAdmitted();
}

final class SubstitutionRejected extends SubstitutionAdmission {
  const SubstitutionRejected(this.reason);

  final String reason;
}

/// Completed-substitution admission. No competition profile is consulted.
SubstitutionAdmission evaluateSubstitutionAdmission({
  required String matchId,
  required SubstitutionPayload payload,
  required List<MatchParticipantTeamBinding> bindings,
}) {
  if (payload.outgoingParticipantId == payload.incomingParticipantId) {
    return const SubstitutionRejected('same identity');
  }
  final outgoing = assessParticipantTeamBinding(
    matchId: matchId,
    participantId: payload.outgoingParticipantId,
    bindings: bindings,
  );
  final incoming = assessParticipantTeamBinding(
    matchId: matchId,
    participantId: payload.incomingParticipantId,
    bindings: bindings,
  );
  if (outgoing is MissingParticipantTeamBinding ||
      incoming is MissingParticipantTeamBinding) {
    return const SubstitutionRejected('missing team binding');
  }
  if (outgoing is AmbiguousParticipantTeamBinding ||
      incoming is AmbiguousParticipantTeamBinding) {
    return const SubstitutionRejected('ambiguous team binding');
  }
  final outgoingTeam = (outgoing as TrustedParticipantTeamBinding).binding.teamId;
  final incomingTeam = (incoming as TrustedParticipantTeamBinding).binding.teamId;
  if (outgoingTeam != incomingTeam) {
    return const SubstitutionRejected('cross-team substitution');
  }
  if (outgoingTeam != payload.teamId) {
    return const SubstitutionRejected('team evidence does not match');
  }
  return const SubstitutionAdmitted();
}
