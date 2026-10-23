import 'mobile_command.dart';
import 'command_authority_gate.dart';
import 'mobile_command_availability.dart';

enum MobileCommitCompleteness { none, partial, complete }

sealed class MobileWriterAdmission {
  const MobileWriterAdmission();
}

final class MobileWriterSaved extends MobileWriterAdmission {
  const MobileWriterSaved({this.committedRecordId});

  final String? committedRecordId;
}

final class MobileWriterFailed extends MobileWriterAdmission {
  const MobileWriterFailed(this.reason, {this.partial = false});

  final String reason;
  final bool partial;
}

/// Future transport lost the result. Not a failure and not Saved.
final class MobileWriterOutcomeUnknown extends MobileWriterAdmission {
  const MobileWriterOutcomeUnknown();
}

abstract interface class MobileAuthoritativeWriter {
  Future<MobileWriterAdmission> commit(MobileCommandEnvelope envelope);
}

final class MobileCommandOutcome {
  const MobileCommandOutcome({
    required this.commandId,
    required this.status,
    required this.availability,
    required this.writerInvoked,
    required this.completeness,
    this.detail,
    this.committedRecordId,
  });

  final String commandId;
  final MobileCommandStatus status;
  final MobileCommandAvailabilityKind availability;
  final bool writerInvoked;
  final MobileCommitCompleteness completeness;
  final String? detail;
  final String? committedRecordId;

  MobileCommandOutcome copyWith({bool? writerInvoked}) {
    return MobileCommandOutcome(
      commandId: commandId,
      status: status,
      availability: availability,
      writerInvoked: writerInvoked ?? this.writerInvoked,
      completeness: completeness,
      detail: detail,
      committedRecordId: committedRecordId,
    );
  }
}

final class _Receipt {
  const _Receipt({required this.canonical, required this.outcome});

  final String canonical;
  final MobileCommandOutcome outcome;
}

/// Routes a frozen command through the authority gate to one writer.
///
/// Duplicate [MobileCommandEnvelope.commandId] after Saved is recognized and
/// not written again. [MobileCommandStatus.outcomeUnknown] is not retried.
/// Sporting idempotency stays inside the production commit port.
final class MobileCommandDispatcher {
  MobileCommandDispatcher({
    required MobileAuthoritativeWriter writer,
    required MobileAuthoritySnapshot authority,
    CommandAuthorityGate? gate,
  })  : _writer = writer,
        _authority = authority,
        _gate = gate ?? const CommandAuthorityGate();

  final MobileAuthoritativeWriter _writer;
  final MobileAuthoritySnapshot _authority;
  final CommandAuthorityGate _gate;
  final Map<String, MobileCommandStatus> _progress = {};
  final Map<String, _Receipt> _receipts = {};

  MobileAuthoritySnapshot get authority => _authority;

  MobileCommandStatus? progressOf(String commandId) => _progress[commandId];

  Future<MobileCommandOutcome> dispatch(MobileCommandEnvelope envelope) async {
    final canonical = envelope.canonicalBody;
    final prior = _receipts[envelope.commandId];
    if (prior != null && prior.canonical != canonical) {
      return MobileCommandOutcome(
        commandId: envelope.commandId,
        status: MobileCommandStatus.failed,
        availability: MobileCommandAvailabilityKind.unavailable,
        writerInvoked: false,
        completeness: MobileCommitCompleteness.none,
        detail: MobileCommandReason.commandIdentityConflict,
      );
    }
    if (prior != null &&
        (prior.outcome.status == MobileCommandStatus.saved ||
            prior.outcome.status == MobileCommandStatus.outcomeUnknown)) {
      return prior.outcome.copyWith(writerInvoked: false);
    }

    if (envelope.schemaVersion != MobileCommandSchema.version) {
      return _remember(
        envelope,
        MobileCommandOutcome(
          commandId: envelope.commandId,
          status: MobileCommandStatus.unsupported,
          availability: MobileCommandAvailabilityKind.unsupported,
          writerInvoked: false,
          completeness: MobileCommitCompleteness.none,
          detail: MobileCommandReason.schemaMismatch,
        ),
      );
    }

    final decision = _gate.evaluate(
      commandType: envelope.commandType,
      authority: _authority,
    );
    if (decision.kind != MobileCommandAvailabilityKind.available) {
      return _remember(
        envelope,
        MobileCommandOutcome(
          commandId: envelope.commandId,
          status: _statusFor(decision.kind),
          availability: decision.kind,
          writerInvoked: false,
          completeness: MobileCommitCompleteness.none,
          detail: decision.reasonCode,
        ),
      );
    }

    _progress[envelope.commandId] = MobileCommandStatus.dispatching;
    final admission = await _writer.commit(envelope);
    final outcome = switch (admission) {
      MobileWriterSaved(:final committedRecordId) => MobileCommandOutcome(
          commandId: envelope.commandId,
          status: MobileCommandStatus.saved,
          availability: decision.kind,
          writerInvoked: true,
          completeness: MobileCommitCompleteness.complete,
          committedRecordId: committedRecordId,
        ),
      MobileWriterFailed(:final reason, :final partial) => MobileCommandOutcome(
          commandId: envelope.commandId,
          status: MobileCommandStatus.failed,
          availability: decision.kind,
          writerInvoked: true,
          completeness: partial
              ? MobileCommitCompleteness.partial
              : MobileCommitCompleteness.none,
          detail: reason,
        ),
      MobileWriterOutcomeUnknown() => MobileCommandOutcome(
          commandId: envelope.commandId,
          status: MobileCommandStatus.outcomeUnknown,
          availability: decision.kind,
          writerInvoked: true,
          completeness: MobileCommitCompleteness.none,
          detail: 'outcome_unknown',
        ),
    };
    _progress[envelope.commandId] = outcome.status;
    return _remember(envelope, outcome);
  }

  MobileCommandOutcome _remember(
    MobileCommandEnvelope envelope,
    MobileCommandOutcome outcome,
  ) {
    _receipts[envelope.commandId] = _Receipt(
      canonical: envelope.canonicalBody,
      outcome: outcome,
    );
    _progress[envelope.commandId] = outcome.status;
    return outcome;
  }

  MobileCommandStatus _statusFor(MobileCommandAvailabilityKind kind) {
    return switch (kind) {
      MobileCommandAvailabilityKind.authorityRequired =>
        MobileCommandStatus.authorityUnavailable,
      MobileCommandAvailabilityKind.notYetCutOver ||
      MobileCommandAvailabilityKind.unsupported =>
        MobileCommandStatus.unsupported,
      MobileCommandAvailabilityKind.unavailable => MobileCommandStatus.failed,
      MobileCommandAvailabilityKind.available => MobileCommandStatus.ready,
    };
  }
}
