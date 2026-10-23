import 'mobile_command.dart';
import 'mobile_command_identity.dart';

/// Freezes one activation into a command envelope.
///
/// The first freeze wins. Later UI edits cannot retarget that activation.
final class MobileCommandPreparation {
  MobileCommandPreparation({
    MobileCommandIdSource? commandIds,
    MobileCommandIdSource? captureIntentIds,
    DateTime Function()? clock,
  })  : _commandIds = commandIds ?? const UuidCommandIdSource(),
        _captureIntentIds = captureIntentIds ?? const UuidCommandIdSource(),
        _clock = clock ?? DateTime.now;

  final MobileCommandIdSource _commandIds;
  final MobileCommandIdSource _captureIntentIds;
  final DateTime Function() _clock;
  final Map<String, MobileCommandEnvelope> _frozen = {};

  MobileIntentDraft get intentDraft => const MobileIntentDraft();

  MobileCaptureActivation beginActivation() {
    return MobileCaptureActivation(
      commandId: _commandIds.nextId(),
      captureIntentId: _captureIntentIds.nextId(),
    );
  }

  PreparedMobileCommand freezeKickOff({
    required MobileCaptureActivation activation,
    required String matchId,
    required String originDeviceId,
    required int periodIndex,
  }) {
    return PreparedMobileCommand(
      _remember(
        activation,
        () => _envelope(
          activation: activation,
          matchId: matchId,
          originDeviceId: originDeviceId,
          commandType: MobileCommandType.kickOff,
          payload: KickOffCommandPayload(periodIndex: periodIndex),
        ),
      ),
    );
  }

  /// Copies [draft] scoring team once. Scorer and display time are ignored.
  PreparedMobileCommand freezeGoal({
    required MobileCaptureActivation activation,
    required String matchId,
    required String originDeviceId,
    required GoalCaptureDraft draft,
  }) {
    return PreparedMobileCommand(
      _remember(
        activation,
        () {
          final scoringTeamId = draft.scoringTeamId;
          if (scoringTeamId == null || scoringTeamId.isEmpty) {
            throw ArgumentError.value(
              scoringTeamId,
              'scoringTeamId',
              'Goal command requires a scoring team',
            );
          }
          return _envelope(
            activation: activation,
            matchId: matchId,
            originDeviceId: originDeviceId,
            commandType: MobileCommandType.goal,
            payload: GoalCommandPayload(
              scoringTeamId: scoringTeamId,
              captureIntentId: activation.captureIntentId,
            ),
          );
        },
      ),
    );
  }

  PreparedMobileCommand freezeUnsupported({
    required MobileCaptureActivation activation,
    required String matchId,
    required String originDeviceId,
    required MobileCommandType commandType,
  }) {
    if (commandType == MobileCommandType.kickOff ||
        commandType == MobileCommandType.goal) {
      throw ArgumentError.value(
        commandType,
        'commandType',
        'use the typed freeze for cut-over commands',
      );
    }
    return PreparedMobileCommand(
      _remember(
        activation,
        () => _envelope(
          activation: activation,
          matchId: matchId,
          originDeviceId: originDeviceId,
          commandType: commandType,
          payload: const EmptyCommandPayload(),
        ),
      ),
    );
  }

  MobileCommandEnvelope _remember(
    MobileCaptureActivation activation,
    MobileCommandEnvelope Function() build,
  ) {
    final existing = _frozen[activation.commandId];
    if (existing != null) return existing;
    final created = build();
    _frozen[activation.commandId] = created;
    return created;
  }

  MobileCommandEnvelope _envelope({
    required MobileCaptureActivation activation,
    required String matchId,
    required String originDeviceId,
    required MobileCommandType commandType,
    required MobileCommandPayload payload,
  }) {
    return MobileCommandEnvelope(
      commandId: activation.commandId,
      matchId: matchId,
      commandType: commandType,
      origin: MobileCommandOrigin.mobileUi,
      originDeviceId: originDeviceId,
      createdAtLocal: _clock(),
      schemaVersion: MobileCommandSchema.version,
      payload: payload,
    );
  }
}
