import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/features/live_match/yellow_card_capture_overlay.dart';
import 'package:referee_phone/infrastructure/yellow_card/phone_participant_registry_store.dart';

/// Adapts disposable Match Memory projections to referee-facing selector rows.
///
/// Identity and prior-caution state always come from Match Memory. Legacy squad
/// data may only enrich display when it still matches the registration snapshot.
List<YellowParticipantOption> buildYellowParticipantOptions({
  required Match match,
  required ParticipantIdentityProjection identities,
  required DisciplinaryMatchProjection disciplinary,
  required String homeLabel,
  required String awayLabel,
  List<PhoneParticipantRegistryEntry> registryEntries = const [],
}) {
  final registryByRosterId = {
    for (final entry in registryEntries) entry.rosterParticipantId: entry,
  };
  final byCanonicalId = <String, YellowParticipantOption>{};
  for (final identity in identities.participantsByRegisteredId.values) {
    final status = identity.initialStatus ??
        ParticipantStatusAtDetermination.onFieldPlayer;
    final display = _displayFor(
      match: match,
      identity: identity,
      registryByRosterId: registryByRosterId,
    );
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

({int? shirtNumber, String? name}) _displayFor({
  required Match match,
  required ProjectedParticipantIdentity identity,
  required Map<String, PhoneParticipantRegistryEntry> registryByRosterId,
}) {
  final binding = identity.binding;
  switch (binding) {
    case RosterLinkedBinding(:final rosterParticipantId):
      final registry = registryByRosterId[rosterParticipantId];
      final squad = identity.teamSide == ParticipantTeamSide.home
          ? match.squads.home.players
          : match.squads.away.players;
      Player? squadPlayer;
      for (final player in squad) {
        if (player.playerId == rosterParticipantId) {
          squadPlayer = player;
          break;
        }
      }
      if (registry != null) {
        if (squadPlayer == null) {
          return (
            shirtNumber: registry.registeredShirtNumber,
            name: registry.registeredName,
          );
        }
        final shirtMatches = registry.registeredShirtNumber == null ||
            registry.registeredShirtNumber == squadPlayer.shirtNumber;
        final nameMatches = registry.registeredName == null ||
            registry.registeredName == squadPlayer.name;
        if (shirtMatches && nameMatches) {
          return (
            shirtNumber: squadPlayer.shirtNumber,
            name: squadPlayer.name,
          );
        }
        return (
          shirtNumber: registry.registeredShirtNumber,
          name: registry.registeredName,
        );
      }
      if (squadPlayer != null) {
        return (shirtNumber: squadPlayer.shirtNumber, name: squadPlayer.name);
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
