import 'package:forref_match_core/forref_match_core.dart';
import 'package:match_core/match_core.dart';
import 'package:referee_phone/infrastructure/yellow_card/phone_participant_registry_store.dart';
import 'package:referee_phone/match_application/authoritative_capture_command.dart';
import 'package:referee_phone/match_application/match_application_boundary.dart';

/// Production wiring for Yellow Card Match Memory foundation facts.
///
/// Roster snapshot policy:
/// - [registerRosterFromMatch] at Go Live is the initial disciplinary identity
///   snapshot into Match Memory.
/// - Later legacy squad edits do not silently rewrite Match Memory identity
///   (see [PhoneParticipantRegistryStore] display snapshots).
/// - Post–Go Live roster reconciliation remains future work.
///
/// Field entry is never inferred from opening Live Match, kick-off, or Yellow.
final class PhoneMatchFoundation {
  const PhoneMatchFoundation({
    required this.boundary,
    required this.registry,
    this.participantIdGenerator = const SecureMatchParticipantIdGenerator(),
  });

  final MatchApplicationBoundary boundary;
  final PhoneParticipantRegistryStore registry;
  final MatchParticipantIdGenerator participantIdGenerator;

  /// Commits field entry on explicit referee action. Idempotent when already
  /// durably recorded.
  Future<FieldEntryCommitOutcome> commitRefereeEnteredField(
    CaptureContext context,
  ) async {
    final records =
        await boundary.durableStore.readCommittedForMatch(context.matchId);
    if (matchMemoryHasFieldEntry(records)) {
      return const FieldEntryAlreadyCommitted();
    }

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
    if (result is DurableCommitSuccess) {
      return const FieldEntryCommitted();
    }
    return const FieldEntryCommitFailed();
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

sealed class FieldEntryCommitOutcome {
  const FieldEntryCommitOutcome();
}

final class FieldEntryAlreadyCommitted extends FieldEntryCommitOutcome {
  const FieldEntryAlreadyCommitted();
}

final class FieldEntryCommitted extends FieldEntryCommitOutcome {
  const FieldEntryCommitted();
}

final class FieldEntryCommitFailed extends FieldEntryCommitOutcome {
  const FieldEntryCommitFailed();
}
