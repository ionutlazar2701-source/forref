import '../canonical_record_form.dart';
import '../match_record.dart';
import '../ports.dart';

/// Marker: reference implementations must not claim D1 durability.
abstract interface class ReferenceDurabilityMarker {
  /// Always `false` for reference/test Match Memory.
  bool get claimsD1Durability;
}

/// Outcome of [ReferenceOnlyMatchMemory.appendRecord].
sealed class ReferenceAppendResult {
  const ReferenceAppendResult();
}

/// New [recordId] appended, or first commit of this record.
final class ReferenceAppendSuccess extends ReferenceAppendResult {
  const ReferenceAppendSuccess({required this.record});

  final MatchRecord record;
}

/// Same [recordId] and identical canonical content — no state change.
final class ReferenceAppendIdempotentNoOp extends ReferenceAppendResult {
  const ReferenceAppendIdempotentNoOp({required this.existingRecord});

  final MatchRecord existingRecord;
}

/// Same [recordId] but different canonical content — fail closed.
final class ReferenceAppendIdentityConflict extends ReferenceAppendResult {
  const ReferenceAppendIdentityConflict({
    required this.recordId,
    required this.existingRecord,
    required this.rejectedRecord,
  });

  final String recordId;
  final MatchRecord existingRecord;
  final MatchRecord rejectedRecord;
}

/// [originSequence] must be >= 1.
final class ReferenceAppendInvalidOriginSequence extends ReferenceAppendResult {
  const ReferenceAppendInvalidOriginSequence({
    required this.originSequence,
  });

  final int originSequence;
}

/// Same `(matchId, originDeviceId, originSequence)` already committed to another record.
final class ReferenceAppendOriginSequenceConflict extends ReferenceAppendResult {
  const ReferenceAppendOriginSequenceConflict({
    required this.matchId,
    required this.originDeviceId,
    required this.originSequence,
    required this.existingRecord,
    required this.rejectedRecord,
  });

  final String matchId;
  final String originDeviceId;
  final int originSequence;
  final MatchRecord existingRecord;
  final MatchRecord rejectedRecord;
}

/// Per-origin committed sequence view derived only from stored records.
final class OriginSequenceFrontier {
  const OriginSequenceFrontier({
    required this.matchId,
    required this.originDeviceId,
    required this.committedSequences,
    required this.highestContiguousCommitted,
    required this.highestObserved,
    required this.missingSequences,
  });

  final String matchId;
  final String originDeviceId;

  /// Sorted committed origin sequences for this match and origin device.
  final List<int> committedSequences;

  /// Highest sequence `n` where every value in `1..n` is committed.
  final int highestContiguousCommitted;

  /// Maximum committed sequence number, or `0` when none.
  final int highestObserved;

  /// Gaps in `1..highestObserved` with no committed record carrying that sequence.
  final List<int> missingSequences;
}

/// **REFERENCE / TEST ONLY — NOT D1**
///
/// Volatile in-memory Match Memory for semantic proofs only.
/// Does not implement [DurableCommitPort] and must never return
/// [DurableCommitSuccess].
final class ReferenceOnlyMatchMemory
    implements MatchMemory, ReferenceDurabilityMarker {
  ReferenceOnlyMatchMemory();

  final Map<String, MatchRecord> _byRecordId = {};
  final Map<String, MatchRecord> _byOriginSlot = {};
  final List<MatchRecord> _appendOrder = [];

  @override
  bool get claimsD1Durability => false;

  /// Append one immutable record. Never overwrites. Never merges. Never LWW.
  ReferenceAppendResult appendRecord(MatchRecord record) {
    if (record.originSequence < 1) {
      return ReferenceAppendInvalidOriginSequence(
        originSequence: record.originSequence,
      );
    }

    final existingById = _byRecordId[record.recordId];
    if (existingById != null) {
      if (identicalCanonicalRecordContent(existingById, record)) {
        return ReferenceAppendIdempotentNoOp(existingRecord: existingById);
      }
      return ReferenceAppendIdentityConflict(
        recordId: record.recordId,
        existingRecord: existingById,
        rejectedRecord: record,
      );
    }

    final slotKey = _originSlotKey(
      matchId: record.matchId,
      originDeviceId: record.originDeviceId,
      originSequence: record.originSequence,
    );
    final existingAtSlot = _byOriginSlot[slotKey];
    if (existingAtSlot != null) {
      if (existingAtSlot.recordId == record.recordId &&
          identicalCanonicalRecordContent(existingAtSlot, record)) {
        return ReferenceAppendIdempotentNoOp(existingRecord: existingAtSlot);
      }
      return ReferenceAppendOriginSequenceConflict(
        matchId: record.matchId,
        originDeviceId: record.originDeviceId,
        originSequence: record.originSequence,
        existingRecord: existingAtSlot,
        rejectedRecord: record,
      );
    }

    _byRecordId[record.recordId] = record;
    _byOriginSlot[slotKey] = record;
    _appendOrder.add(record);
    return ReferenceAppendSuccess(record: record);
  }

  OriginSequenceFrontier originSequenceFrontier({
    required String matchId,
    required String originDeviceId,
  }) {
    final sequences = <int>{};
    for (final record in _appendOrder) {
      if (record.matchId == matchId &&
          record.originDeviceId == originDeviceId) {
        sequences.add(record.originSequence);
      }
    }

    final sorted = sequences.toList()..sort();
    final highestObserved = sorted.isEmpty ? 0 : sorted.last;

    var highestContiguous = 0;
    for (var sequence = 1; sequence <= highestObserved; sequence++) {
      if (!sequences.contains(sequence)) break;
      highestContiguous = sequence;
    }

    final missing = <int>[];
    for (var sequence = 1; sequence <= highestObserved; sequence++) {
      if (!sequences.contains(sequence)) missing.add(sequence);
    }

    return OriginSequenceFrontier(
      matchId: matchId,
      originDeviceId: originDeviceId,
      committedSequences: sorted,
      highestContiguousCommitted: highestContiguous,
      highestObserved: highestObserved,
      missingSequences: missing,
    );
  }

  @override
  Future<MatchRecord?> getById(String recordId) async =>
      _byRecordId[recordId];

  @override
  Future<List<MatchRecord>> readCommittedForMatch(String matchId) async {
    return [
      for (final record in _appendOrder)
        if (record.matchId == matchId) record,
    ];
  }

  static String _originSlotKey({
    required String matchId,
    required String originDeviceId,
    required int originSequence,
  }) {
    return '$matchId|$originDeviceId|$originSequence';
  }
}
