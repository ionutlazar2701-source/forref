/// Production payload field names for typed semantic interpretation.
///
/// Not foundation/test keys (`projectionFacets`, `facet`, `facets`).
abstract final class ProductionPayloadContract {
  /// Typed semantic identity carried on committed record payload.
  static const semanticType = 'semanticType';

  /// Schema versions with registered production interpreters in this package.
  static const registeredSchemaVersions = {1};
}
