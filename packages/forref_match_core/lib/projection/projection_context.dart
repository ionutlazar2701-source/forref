import 'projection_trust.dart';

/// Explicit inputs for a deterministic projection rebuild.
final class ProjectionContext {
  const ProjectionContext({
    required this.evaluatedAuthorityGeneration,
    this.trackedFacets = const [
      ProjectionFacet.coverage,
      ProjectionFacet.authority,
      ProjectionFacet.dependencies,
      ProjectionFacet.temporal,
      ProjectionFacet.score,
      ProjectionFacet.disciplinary,
    ],
  });

  /// Active MAIN_REFEREE authority generation boundary for this projection.
  final int evaluatedAuthorityGeneration;

  /// Facets the projector evaluates. Others remain absent from the result.
  final List<String> trackedFacets;
}
