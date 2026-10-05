import 'capture/authoritative_record_commit_request.dart';
import 'match_record.dart';
import 'temporal.dart';

/// Read-only access to committed Match Memory.
abstract interface class MatchMemory {
  Future<MatchRecord?> getById(String recordId);

  /// Committed records for [matchId] in commit order (implementation-defined sort).
  Future<List<MatchRecord>> readCommittedForMatch(String matchId);
}

/// Outcome of [DurableCommitPort.commit]. No ambiguous or "probably committed" state.
sealed class DurableCommitResult {
  const DurableCommitResult();
}

/// D1 durable commit succeeded for exactly one record.
///
/// Returned only by a **certified persistence adapter** after local durability
/// is confirmed. Test/reference implementations must not return this.
final class DurableCommitSuccess extends DurableCommitResult {
  const DurableCommitSuccess({
    required this.committedRecordId,
    this.diagnostics,
  });

  final String committedRecordId;
  final String? diagnostics;
}

/// D1 durable commit failed for the requested record.
final class DurableCommitFailure extends DurableCommitResult {
  const DurableCommitFailure({
    required this.recordId,
    required this.reason,
  });

  final String recordId;
  final String reason;
}

/// Append-only durable write boundary. Atomic unit: one immutable [MatchRecord].
///
/// Must finish before any Saved acknowledgement. Batch commit is out of scope.
abstract interface class DurableCommitPort {
  Future<DurableCommitResult> commit(MatchRecord record);
}

/// Allocates the next origin sequence and commits in one authoritative operation.
///
/// Origin sequence advancement must not persist independently from its record.
abstract interface class AuthoritativeOriginCommitPort {
  /// Allocates the next origin sequence and commits one record.
  ///
  /// [rejectCommitted] runs inside the same durable transaction, before the
  /// sequence is assigned. A non-null reason rolls back and consumes no sequence.
  Future<DurableCommitResult> commitAtNextOriginSequence(
    AuthoritativeRecordCommitRequest request, {
    String? Function(List<MatchRecord> committedForMatch)? rejectCommitted,
  });
}

/// Resolves temporal evidence referenced from records (implementation later).
abstract interface class TemporalEvidencePort {
  Future<TemporalEvidence?> resolve(String evidenceId);
}

/// Disposable projection artifact. Never Match Memory.
abstract interface class MatchProjection {
  String get matchId;
}

/// Deterministic projector: rebuilds [P] from [MatchMemory], not mutable current state.
abstract interface class MatchProjector<P extends MatchProjection> {
  Future<P> project(MatchMemory memory, String matchId);
}
