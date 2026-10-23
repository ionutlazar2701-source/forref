import 'projection_trust.dart';
import 'score_completeness_proof.dart';

/// Explicit inputs for a deterministic projection rebuild.
final class ProjectionContext {
  const ProjectionContext({
    required this.evaluatedAuthorityGeneration,
    this.scoreCompletenessProof,
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

  /// Positive score completeness proof. Without it, score stays unavailable.
  final ScoreCompletenessProof? scoreCompletenessProof;

  /// Facets the projector evaluates. Others remain absent from the result.
  final List<String> trackedFacets;
}
