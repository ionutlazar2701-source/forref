import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/features/live_match/yellow_card_capture_overlay.dart';

/// Adapts disposable Match Memory projections to referee-facing selector rows.
///
/// Legacy squad data supplies display text only. Identity and prior-caution
/// state always come from Match Memory.
List<YellowParticipantOption> buildYellowParticipantOptions({
  required Match match,
  required ParticipantIdentityProjection identities,
  required DisciplinaryMatchProjection disciplinary,
  required String homeLabel,
  required String awayLabel,
}) {
  final byCanonicalId = <String, YellowParticipantOption>{};
  for (final identity in identities.participantsByRegisteredId.values) {
    final status = identity.initialStatus ??
        ParticipantStatusAtDetermination.onFieldPlayer;
    final display = _displayFor(match, identity);
    final option = YellowParticipantOption(
      participantRef: identity.toRef(),
      status: status,
      identityConfidence: identity.confidence,
      priorAwareness: _priorAwareness(identity, disciplinary),
      teamLabel:
          identity.teamSide == ParticipantTeamSide.home ? homeLabel : awayLabel,
      shirtNumber: display.shirtNumber,
      displayName: display.name,
    );
    byCanonicalId.putIfAbsent(identity.canonicalId.value, () => option);
  }
  final options = byCanonicalId.values.toList()
    ..sort((left, right) {
      final side = left.participantRef.teamSide.index
          .compareTo(right.participantRef.teamSide.index);
      if (side != 0) return side;
      final leftNumber = left.shirtNumber ?? 1000;
      final rightNumber = right.shirtNumber ?? 1000;
      final number = leftNumber.compareTo(rightNumber);
      if (number != 0) return number;
      return (left.displayName ?? '').compareTo(right.displayName ?? '');
    });
  return options;
}

YellowPriorAwareness _priorAwareness(
  ProjectedParticipantIdentity identity,
  DisciplinaryMatchProjection disciplinary,
) {
  if (identity.confidence == IdentityConfidence.conflicted ||
      disciplinary.participantIdentityTrust == ProjectionTrust.conflicted ||
      disciplinary.disciplinaryFacetTrust == ProjectionTrust.conflicted) {
    return YellowPriorAwareness.conflicted;
  }
  if (identity.confidence == IdentityConfidence.ambiguous ||
      disciplinary.participantIdentityTrust == ProjectionTrust.incomplete ||
      disciplinary.participantIdentityTrust == ProjectionTrust.untrusted) {
    return YellowPriorAwareness.unknownIdentity;
  }
  if (disciplinary.disciplinaryFacetTrust == ProjectionTrust.incomplete ||
      disciplinary.disciplinaryFacetTrust == ProjectionTrust.untrusted) {
    return YellowPriorAwareness.unknownHistory;
  }
  final assessment = disciplinary.priorCautionStateFor(
    participantId: identity.canonicalId,
    accountingScope: disciplinary.disciplinaryAccountingScope,
  );
  return switch (assessment.state) {
    PriorCautionState.none => YellowPriorAwareness.noneConfirmed,
    PriorCautionState.standing => YellowPriorAwareness.exists,
    PriorCautionState.unresolved =>
      _hasIdentityConsequence(identity, disciplinary)
          ? YellowPriorAwareness.unknownIdentity
          : YellowPriorAwareness.unknownHistory,
  };
}

bool _hasIdentityConsequence(
  ProjectedParticipantIdentity identity,
  DisciplinaryMatchProjection disciplinary,
) {
  for (final consequence in disciplinary.unresolvedConsequences) {
    final identityCode = consequence.code ==
            UnresolvedDisciplinaryConsequenceCode
                .participantIdentityUnresolved ||
        consequence.code ==
            UnresolvedDisciplinaryConsequenceCode.participantIdentityConflicted;
    if (!identityCode) continue;
    final participant = consequence.canonicalParticipantId;
    if (participant == null || participant == identity.canonicalId) return true;
  }
  return false;
}

({int? shirtNumber, String? name}) _displayFor(
  Match match,
  ProjectedParticipantIdentity identity,
) {
  final binding = identity.binding;
  switch (binding) {
    case RosterLinkedBinding(:final rosterParticipantId):
      final squad = identity.teamSide == ParticipantTeamSide.home
          ? match.squads.home.players
          : match.squads.away.players;
      for (final player in squad) {
        if (player.playerId == rosterParticipantId) {
          return (shirtNumber: player.shirtNumber, name: player.name);
        }
      }
      return (shirtNumber: null, name: null);
    case TeamScopedNumberBinding(:final shirtNumber):
      return (shirtNumber: shirtNumber, name: null);
    case FreeformDescriptorBinding(:final descriptor):
      return (shirtNumber: null, name: descriptor);
    case IdentifiedOfficialBinding(:final displayName):
      return (shirtNumber: null, name: displayName);
    case SeniorCoachPresentBinding():
      return (shirtNumber: null, name: null);
  }
}
