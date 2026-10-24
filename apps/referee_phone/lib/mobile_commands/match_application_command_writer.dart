import 'package:forref_match_core/forref_match_core.dart';

import '../match_application/kick_off_authority.dart';
import '../match_application/match_application_boundary.dart';
import 'mobile_command.dart';
import 'mobile_command_dispatcher.dart';

/// Boundary text used when a match-start success cannot be re-read.
///
/// Absence after that claim is not proof of rollback.
const matchStartedMissingAfterSuccessReason = 'MATCH_STARTED was not saved';

/// Adapts frozen mobile commands onto the existing phone commit boundary.
///
/// This type does not call the legacy mutable match aggregate.
///
/// A returned [DurableCommitSuccess] is Saved. A known failure is Not saved
/// only after a healthy Match Memory read proves the attempt is absent or is
/// a positive idempotency conflict. Quarantine, a failed read, or a success
/// claim that cannot be found stays [MobileWriterOutcomeUnknown].
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
    try {
      final result = await _boundary.commitKickOff(
        context,
        period: PeriodIdentity(index: payload.periodIndex),
        periodAnchor: _periodAnchor,
      );
      return switch (result) {
        KickOffAuthorityCommitted(:final periodStartedRecordId) =>
          MobileWriterSaved(committedRecordId: periodStartedRecordId),
        KickOffAlreadyStarted() => const MobileWriterSaved(),
        KickOffMatchStartedIncomplete() ||
        KickOffAuthorityRejected() =>
          await _reconcileKickOff(context, payload, result),
      };
    } catch (_) {
      return _reconcileKickOff(context, payload, null);
    }
  }

  Future<MobileWriterAdmission> _goal(
    CaptureContext context,
    MobileCommandEnvelope envelope,
  ) async {
    final payload = envelope.payload;
    if (payload is! GoalCommandPayload) {
      return const MobileWriterFailed('goal payload mismatch');
    }
    try {
      final result = await _boundary.commitGoal(
        context,
        scoringTeamId: MatchTeamId(payload.scoringTeamId),
        captureIntentId: payload.captureIntentId,
      );
      return switch (result) {
        DurableCommitSuccess(:final committedRecordId) =>
          await _confirmGoal(context, payload, committedRecordId),
        DurableCommitFailure() =>
          await _reconcileGoal(context, payload, result),
      };
    } catch (_) {
      return _reconcileGoal(context, payload, null);
    }
  }

  Future<MobileWriterAdmission> _confirmGoal(
    CaptureContext context,
    GoalCommandPayload payload,
    String committedRecordId,
  ) async {
    final records = await _read(context.matchId);
    if (records == null) return const MobileWriterOutcomeUnknown();
    final matches = _goalsForIntent(records, payload.captureIntentId);
    if (matches.length != 1) return const MobileWriterOutcomeUnknown();
    final record = matches.single;
    final body = record.payload as GoalPayload;
    if (!_sameCaptureAuthority(record, context) ||
        body.scoringTeamId.value != payload.scoringTeamId ||
        record.recordId != committedRecordId) {
      return const MobileWriterOutcomeUnknown();
    }
    return MobileWriterSaved(committedRecordId: record.recordId);
  }

  Future<MobileWriterAdmission> _reconcileGoal(
    CaptureContext context,
    GoalCommandPayload payload,
    DurableCommitFailure? failure,
  ) async {
    final records = await _read(context.matchId);
    if (records == null) return const MobileWriterOutcomeUnknown();

    final matches = _goalsForIntent(records, payload.captureIntentId);
    if (matches.length > 1) return const MobileWriterOutcomeUnknown();
    if (matches.isEmpty) {
      if (failure != null) return MobileWriterFailed(failure.reason);
      return const MobileWriterFailed('goal was not committed');
    }

    final record = matches.single;
    if (!_sameCaptureAuthority(record, context)) {
      return const MobileWriterOutcomeUnknown();
    }
    final body = record.payload as GoalPayload;
    if (body.scoringTeamId.value != payload.scoringTeamId) {
      return MobileWriterFailed(
        failure?.reason ??
            'idempotency conflict: capture intent ${payload.captureIntentId} '
                'already bound to a different goal meaning',
      );
    }
    return MobileWriterSaved(committedRecordId: record.recordId);
  }

  Future<MobileWriterAdmission> _reconcileKickOff(
    CaptureContext context,
    KickOffCommandPayload payload,
    KickOffAuthorityResult? result,
  ) async {
    final records = await _read(context.matchId);
    if (records == null) return const MobileWriterOutcomeUnknown();

    final starts = records.where(_isMatchStarted).toList();
    final periods = records
        .where((record) => _isPeriodStarted(record, payload.periodIndex))
        .toList();
    if (starts.any((record) => !_sameCaptureAuthority(record, context)) ||
        periods.any((record) => !_sameCaptureAuthority(record, context)) ||
        starts.length > 1 ||
        periods.length > 1) {
      return const MobileWriterOutcomeUnknown();
    }
    if (periods.length == 1 && starts.length == 1) {
      return MobileWriterSaved(committedRecordId: periods.single.recordId);
    }
    if (periods.length == 1) return const MobileWriterOutcomeUnknown();
    if (starts.length == 1) {
      final reason = result is KickOffMatchStartedIncomplete
          ? result.periodFailureReason
          : 'PERIOD_STARTED was not committed';
      return MobileWriterFailed(reason, partial: true);
    }

    if (result is KickOffAuthorityRejected &&
        result.reason != matchStartedMissingAfterSuccessReason) {
      return MobileWriterFailed(result.reason);
    }
    if (result == null) {
      return const MobileWriterFailed('kick-off was not committed');
    }
    return const MobileWriterOutcomeUnknown();
  }

  List<MatchRecord> _goalsForIntent(
      List<MatchRecord> records, String intentId) {
    return [
      for (final record in records)
        if (record.payload is GoalPayload &&
            (record.payload as GoalPayload).captureIntentId == intentId)
          record,
    ];
  }

  /// Null means the read could not prove presence or absence.
  Future<List<MatchRecord>?> _read(String matchId) async {
    try {
      return await _boundary.durableStore.readCommittedForMatch(matchId);
    } catch (_) {
      return null;
    }
  }

  bool _sameCaptureAuthority(MatchRecord record, CaptureContext context) {
    final authority = record.authorityContext;
    return record.matchId == context.matchId &&
        record.originDeviceId == context.originDeviceId &&
        authority?.principal?.principalId == context.authorityPrincipalId &&
        authority?.generation?.value == context.authorityGeneration;
  }

  bool _isMatchStarted(MatchRecord record) {
    final payload = record.payload;
    return record.recordKind == RecordKind.temporalFact &&
        payload is TemporalTransitionPayload &&
        payload.semanticType == V1SemanticTypeCode.matchStarted;
  }

  bool _isPeriodStarted(MatchRecord record, int periodIndex) {
    final payload = record.payload;
    return record.recordKind == RecordKind.temporalFact &&
        payload is TemporalTransitionPayload &&
        payload.semanticType == V1SemanticTypeCode.periodStarted &&
        payload.period?.index == periodIndex;
  }
}
