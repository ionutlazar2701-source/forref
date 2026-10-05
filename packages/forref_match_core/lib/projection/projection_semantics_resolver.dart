import '../match_record.dart';

/// Whether a resolver can declare sporting projection semantics for a record.
enum SemanticSupportStatus {
  supported,
  unsupported,
}

/// Declared semantic projection contribution for one committed record.
final class SemanticProjectionContribution {
  const SemanticProjectionContribution({
    required this.status,
    this.supportedFacets = const [],
    this.missingRequiredRelationship = false,
    this.requiredTargetRecordId,
  });

  final SemanticSupportStatus status;
  final List<String> supportedFacets;

  /// The semantic is recognized, but a required target link is absent.
  final bool missingRequiredRelationship;

  /// Target record id when a required correction or supersession link is present.
  final String? requiredTargetRecordId;

  bool get isSupported =>
      status == SemanticSupportStatus.supported && supportedFacets.isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is SemanticProjectionContribution &&
        status == other.status &&
        _listEquals(supportedFacets, other.supportedFacets) &&
        missingRequiredRelationship == other.missingRequiredRelationship &&
        requiredTargetRecordId == other.requiredTargetRecordId;
  }

  @override
  int get hashCode => Object.hash(
        status,
        Object.hashAll(supportedFacets),
        missingRequiredRelationship,
        requiredTargetRecordId,
      );
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Explicit contract: [MatchRecord] → declared semantic projection contribution.
///
/// The core projector consumes this abstraction only. Payload interpretation
/// belongs in resolver implementations, not in projection mechanics.
abstract interface class ProjectionSemanticsResolver {
  SemanticProjectionContribution resolve(MatchRecord record);
}
