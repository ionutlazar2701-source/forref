import '../match_record.dart';
import '../payload.dart';
import 'projection_semantics_resolver.dart';

/// FOUNDATION / TEST SEMANTICS ONLY — NOT FROZEN EXTERNAL PAYLOAD CONTRACT.
///
/// Interprets legacy foundation payload keys for current tests:
/// `projectionFacets`, `facet`, `facets`.
///
/// Do not treat this resolver or its payload keys as the long-term FORREF
/// sporting-semantics protocol.
final class FoundationPayloadSemanticsResolver
    implements ProjectionSemanticsResolver {
  const FoundationPayloadSemanticsResolver();

  /// Test/foundation payload keys only. Not a frozen external contract.
  static const projectionFacets = 'projectionFacets';
  static const legacyFacet = 'facet';
  static const legacyFacets = 'facets';

  @override
  SemanticProjectionContribution resolve(MatchRecord record) {
    final facets = _readFoundationPayloadFacets(record);
    if (facets.isEmpty) {
      return const SemanticProjectionContribution(
        status: SemanticSupportStatus.unsupported,
      );
    }
    return SemanticProjectionContribution(
      status: SemanticSupportStatus.supported,
      supportedFacets: facets,
    );
  }

  static List<String> _readFoundationPayloadFacets(MatchRecord record) {
    if (record.payload is! StructuredPayload) return const [];
    final fields = (record.payload as StructuredPayload).fields;

    final projectionFacets = fields[FoundationPayloadSemanticsResolver.projectionFacets];
    if (projectionFacets is List) {
      return [
        for (final value in projectionFacets)
          if (value is String) value,
      ];
    }

    final legacyFacet = fields[FoundationPayloadSemanticsResolver.legacyFacet];
    if (legacyFacet is String) return [legacyFacet];

    final legacyFacets = fields[FoundationPayloadSemanticsResolver.legacyFacets];
    if (legacyFacets is List) {
      return [
        for (final value in legacyFacets)
          if (value is String) value,
      ];
    }

    return const [];
  }
}
