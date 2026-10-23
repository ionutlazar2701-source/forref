import 'package:forref_match_core/forref_match_core.dart';

import '../match_application/kick_off_authority.dart';
import '../match_application/match_application_boundary.dart';
import 'mobile_command.dart';
import 'mobile_command_dispatcher.dart';

/// Adapts frozen mobile commands onto the existing phone commit boundary.
///
/// This type does not call the legacy mutable match aggregate.
final class MatchApplicationCommandWriter implements MobileAuthoritativeWriter {
  MatchApplicationCommandWriter({
    required MatchApplicationBoundary boundary,
    required Future<CaptureContext?> Function(String matchId) captureContext,
    Future<TemporalContext> Function()? periodAnchor,
  })  : _boundary = boundary,
        _captureContext = captureContext,
        _periodAnchor = periodAnchor;

  final MatchApplicationBoundary _boundary;
  final Future<CaptureContext?> Function(String matchId) _captureContext;
  final Future<TemporalContext> Function()? _periodAnchor;

  @override
  Future<MobileWriterAdmission> commit(MobileCommandEnvelope envelope) async {
    final context = await _captureContext(envelope.matchId);
    if (context == null) {
      return const MobileWriterFailed('capture context unavailable');
    }
    if (context.matchId != envelope.matchId ||
        context.originDeviceId != envelope.originDeviceId) {
      return const MobileWriterFailed('capture context does not match command');
    }
    return switch (envelope.commandType) {
      MobileCommandType.kickOff => _kickOff(context, envelope),
      MobileCommandType.goal => _goal(context, envelope),
      _ => const MobileWriterFailed('command is not a production writer'),
    };
  }

  Future<MobileWriterAdmission> _kickOff(
    CaptureContext context,
    MobileCommandEnvelope envelope,
  ) async {
    final payload = envelope.payload;
    if (payload is! KickOffCommandPayload) {
      return const MobileWriterFailed('kick-off payload mismatch');
    }
    final result = await _boundary.commitKickOff(
      context,
      period: PeriodIdentity(index: payload.periodIndex),
      periodAnchor: _periodAnchor,
    );
    return switch (result) {
      KickOffAuthorityCommitted(:final periodStartedRecordId) =>
        MobileWriterSaved(committedRecordId: periodStartedRecordId),
      KickOffAlreadyStarted() => const MobileWriterSaved(),
      KickOffMatchStartedIncomplete(:final periodFailureReason) =>
        MobileWriterFailed(periodFailureReason, partial: true),
      KickOffAuthorityRejected(:final reason) => MobileWriterFailed(reason),
    };
  }

  Future<MobileWriterAdmission> _goal(
    CaptureContext context,
    MobileCommandEnvelope envelope,
  ) async {
    final payload = envelope.payload;
    if (payload is! GoalCommandPayload) {
      return const MobileWriterFailed('goal payload mismatch');
    }
    final result = await _boundary.commitGoal(
      context,
      scoringTeamId: MatchTeamId(payload.scoringTeamId),
      captureIntentId: payload.captureIntentId,
    );
    return switch (result) {
      DurableCommitSuccess(:final committedRecordId) =>
        MobileWriterSaved(committedRecordId: committedRecordId),
      DurableCommitFailure(:final reason) => MobileWriterFailed(reason),
    };
  }
}
