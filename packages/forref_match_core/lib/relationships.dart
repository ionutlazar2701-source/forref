/// Typed link from this record to another record id.
///
/// [RelatesTo] is non-causal and must not be used where causal dependency
/// is required — use [CausalDependency] instead.
sealed class RecordRelationship {
  const RecordRelationship({required this.targetRecordId});

  final String targetRecordId;
}

/// This record causally depends on [targetRecordId].
final class CausalDependency extends RecordRelationship {
  const CausalDependency({required super.targetRecordId});
}

/// This record corrects [targetRecordId] (paired with [RecordKind.correction]).
final class CorrectionTarget extends RecordRelationship {
  const CorrectionTarget({required super.targetRecordId});
}

/// This record legally supersedes [targetRecordId]
/// (paired with [RecordKind.legalSupersession]).
final class LegalSupersessionTarget extends RecordRelationship {
  const LegalSupersessionTarget({required super.targetRecordId});
}

/// Non-causal association. Not a substitute for [CausalDependency].
final class RelatesTo extends RecordRelationship {
  const RelatesTo({required super.targetRecordId});
}
