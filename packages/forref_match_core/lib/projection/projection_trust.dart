/// Facet-level projection trust. Not a single global match truth.
enum ProjectionTrust {
  trusted,
  incomplete,
  conflicted,
  untrusted,
}

/// Trust state for one disposable projection facet.
final class FacetTrust {
  const FacetTrust({
    required this.facetId,
    required this.trust,
    this.reason,
  });

  final String facetId;
  final ProjectionTrust trust;
  final String? reason;

  @override
  bool operator ==(Object other) {
    return other is FacetTrust &&
        facetId == other.facetId &&
        trust == other.trust &&
        reason == other.reason;
  }

  @override
  int get hashCode => Object.hash(facetId, trust, reason);
}

/// Standard facet identifiers for the foundation projector.
abstract final class ProjectionFacet {
  static const coverage = 'coverage';
  static const authority = 'authority';
  static const dependencies = 'dependencies';
  static const temporal = 'temporal';
  static const score = 'score';
  static const disciplinary = 'disciplinary';
  static const identity = 'identity';
  static const disciplinaryState = 'disciplinaryState';
  static const disciplinaryAccountingScope = 'disciplinaryAccountingScope';
}
