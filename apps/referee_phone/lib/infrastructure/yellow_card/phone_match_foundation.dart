import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/infrastructure/yellow_card/phone_participant_registry_store.dart';
import 'package:referee_phone/match_application/authoritative_capture_command.dart';
import 'package:referee_phone/match_application/match_application_boundary.dart';

/// Production wiring for Yellow Card Match Memory foundation facts.
///
/// Does not fabricate roster completeness or equate kick-off with field entry.
final class PhoneMatchFoundation {
  const PhoneMatchFoundation({
    required this.boundary,
    required this.registry,
    this.participantIdGenerator = const SecureMatchParticipantIdGenerator(),
  });

  final MatchApplicationBoundary boundary;
  final PhoneParticipantRegistryStore registry;
  final MatchParticipantIdGenerator participantIdGenerator;

  Future<bool> ensureRefereeEnteredField(CaptureContext context) async {
    final records =
        await boundary.durableStore.readCommittedForMatch(context.matchId);
    final already = records.any(
      (record) =>
          record.payload is TemporalTransitionPayload &&
          (record.payload as TemporalTransitionPayload).semanticType ==
              V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
    );
    if (already) return true;

    final result = await boundary.captureAndCommit(
      AuthoritativeCaptureCommand(
        context: context,
        recordKind: RecordKind.temporalFact,
        payload: TemporalTransitionPayload(
          semanticType: V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
        ),
        integrity: const IntegrityMetadata(),
      ),
    );
    return result is DurableCommitSuccess;
  }

  Future<void> registerRosterFromMatch({
    required CaptureContext context,
    required Match match,
  }) async {
    final records =
        await boundary.durableStore.readCommittedForMatch(context.matchId);
    final registeredIds = {
      for (final record in records)
        if (record.payload is ParticipantRegisteredPayload)
          (record.payload as ParticipantRegisteredPayload)
              .matchParticipantId,
    };

    for (final player in match.squads.home.players) {
      await _registerPlayer(
        context: context,
        teamSide: ParticipantTeamSide.home,
        player: player,
        registeredIds: registeredIds,
      );
    }
    for (final player in match.squads.away.players) {
      await _registerPlayer(
        context: context,
        teamSide: ParticipantTeamSide.away,
        player: player,
        registeredIds: registeredIds,
      );
    }
  }

  Future<void> _registerPlayer({
    required CaptureContext context,
    required ParticipantTeamSide teamSide,
    required Player player,
    required Set<MatchParticipantId> registeredIds,
  }) async {
    final existingRegistry = await registry.entryForRosterId(
      matchId: context.matchId,
      rosterParticipantId: player.playerId,
    );
    final participantId = existingRegistry?.matchParticipantId ??
        participantIdGenerator.newParticipantId();
    if (registeredIds.contains(participantId)) {
      return;
    }

    final initialStatus = _statusFor(player.role);
    final result = await boundary.captureAndCommit(
      AuthoritativeCaptureCommand(
        context: context,
        recordKind: RecordKind.action,
        payload: ParticipantRegisteredPayload(
          matchParticipantId: participantId,
          teamSide: teamSide,
          binding: RosterLinkedBinding(rosterParticipantId: player.playerId),
          initialStatus: initialStatus,
        ),
        integrity: const IntegrityMetadata(),
      ),
    );
    if (result is! DurableCommitSuccess) {
      return;
    }
    registeredIds.add(participantId);
    await registry.saveEntry(
      context.matchId,
      PhoneParticipantRegistryEntry(
        matchParticipantId: participantId,
        rosterParticipantId: player.playerId,
        teamSide: teamSide,
        initialStatus: initialStatus,
        registeredShirtNumber: player.shirtNumber,
        registeredName: player.name,
      ),
    );
  }

  ParticipantStatusAtDetermination _statusFor(PlayerRole? role) {
    return switch (role) {
      PlayerRole.substitute => ParticipantStatusAtDetermination.substitute,
      PlayerRole.starter ||
      null =>
        ParticipantStatusAtDetermination.onFieldPlayer,
    };
  }
}

bool matchMemoryHasFieldEntry(List<MatchRecord> records) {
  return records.any(
    (record) =>
        record.payload is TemporalTransitionPayload &&
        (record.payload as TemporalTransitionPayload).semanticType ==
            V1SemanticTypeCode.refereeEnteredFieldForMatchStart,
  );
}

bool matchMemoryHasParticipantRegistrations(List<MatchRecord> records) {
  return records.any((record) => record.payload is ParticipantRegisteredPayload);
}
