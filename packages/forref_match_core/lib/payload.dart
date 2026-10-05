/// Immutable payload boundary. Committed payload semantics are not mutated in place.
abstract class MatchRecordPayload {
  const MatchRecordPayload();
}

/// Structured payload with frozen field map (foundation placeholder for typed payloads).
final class StructuredPayload extends MatchRecordPayload {
  StructuredPayload(Map<String, Object?> fields)
      : fields = Map.unmodifiable(fields);

  final Map<String, Object?> fields;
}
