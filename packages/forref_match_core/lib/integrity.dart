/// Integrity evidence boundary carried with the record.
///
/// Concrete algorithms, checksums, and authentication belong to Security
/// Authority (later). Foundation does not prescribe hash or signature schemes.
final class IntegrityMetadata {
  const IntegrityMetadata({this.evidenceRefs = const []});

  /// Opaque references to integrity evidence bundles (no algorithm chosen here).
  final List<String> evidenceRefs;
}
