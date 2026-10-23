// Mobile command vocabulary.
//
// An intent is an ephemeral selection. A command is a frozen request.
// Neither is a Match Record. Saved is decided only after durable commit.

enum MobileCommandStatus {
  draft,
  ready,
  dispatching,
  saved,
  failed,
  outcomeUnknown,
  unsupported,
  authorityUnavailable,
}

enum MobileCommandType {
  kickOff,
  goal,
  yellow,
  directSendOff,
  secondCautionSendOff,
  substitution,
  fullTime,
  finishMatch,
}

/// Where the request was formed. This is not sporting authority.
enum MobileCommandOrigin { mobileUi }

abstract final class MobileCommandSchema {
  static const version = 1;
}

/// Stable identity for one user activation.
///
/// Retry of the same activation keeps both ids. A new activation allocates
/// new ids. [commandId] is transport identity. [captureIntentId] is the
/// production idempotency key when the production contract uses one.
final class MobileCaptureActivation {
  const MobileCaptureActivation({
    required this.commandId,
    required this.captureIntentId,
  });

  final String commandId;
  final String captureIntentId;
}

/// Ephemeral goal selection. Scorer and display time never enter the payload.
final class GoalCaptureDraft {
  String? scoringTeamId;
  String? scorerLabel;
  String? displayMatchTime;
}

sealed class MobileCommandPayload {
  const MobileCommandPayload();
}

final class KickOffCommandPayload extends MobileCommandPayload {
  const KickOffCommandPayload({required this.periodIndex});

  final int periodIndex;

  @override
  bool operator ==(Object other) =>
      other is KickOffCommandPayload && other.periodIndex == periodIndex;

  @override
  int get hashCode => periodIndex;

  @override
  String toString() => 'KickOffCommandPayload($periodIndex)';
}

/// Production Goal semantics: scoring team and capture intent only.
final class GoalCommandPayload extends MobileCommandPayload {
  const GoalCommandPayload({
    required this.scoringTeamId,
    required this.captureIntentId,
  });

  final String scoringTeamId;
  final String captureIntentId;

  @override
  bool operator ==(Object other) =>
      other is GoalCommandPayload &&
      other.scoringTeamId == scoringTeamId &&
      other.captureIntentId == captureIntentId;

  @override
  int get hashCode => Object.hash(scoringTeamId, captureIntentId);

  @override
  String toString() => 'GoalCommandPayload($scoringTeamId, $captureIntentId)';
}

final class EmptyCommandPayload extends MobileCommandPayload {
  const EmptyCommandPayload();

  @override
  bool operator ==(Object other) => other is EmptyCommandPayload;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'EmptyCommandPayload()';
}

/// Frozen semantic request. Safe to retry. Not yet a Match Record.
final class MobileCommandEnvelope {
  const MobileCommandEnvelope({
    required this.commandId,
    required this.matchId,
    required this.commandType,
    required this.origin,
    required this.originDeviceId,
    required this.createdAtLocal,
    required this.schemaVersion,
    required this.payload,
  });

  final String commandId;
  final String matchId;
  final MobileCommandType commandType;
  final MobileCommandOrigin origin;
  final String originDeviceId;
  final DateTime createdAtLocal;
  final int schemaVersion;
  final MobileCommandPayload payload;

  String get canonicalBody {
    final payloadBody = switch (payload) {
      KickOffCommandPayload(:final periodIndex) => 'kick:$periodIndex',
      GoalCommandPayload(:final scoringTeamId, :final captureIntentId) =>
        'goal:$scoringTeamId:$captureIntentId',
      EmptyCommandPayload() => 'empty',
    };
    return '$commandId|${commandType.name}|$matchId|$originDeviceId|'
        '${origin.name}|$schemaVersion|$payloadBody';
  }
}

/// Prepared command waiting for the authority gate.
final class PreparedMobileCommand {
  const PreparedMobileCommand(this.envelope);

  final MobileCommandEnvelope envelope;

  MobileCommandStatus get status => MobileCommandStatus.ready;
}

/// User desire before freeze.
final class MobileIntentDraft {
  const MobileIntentDraft();

  MobileCommandStatus get status => MobileCommandStatus.draft;
}
