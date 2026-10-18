import '../ports.dart';
import 'projection_trust.dart';
import 'score_projection.dart';

/// Disposable deterministic projection over committed Match Memory.
final class MatchProjectionState implements MatchProjection {
  MatchProjectionState({
    required this.matchId,
    required this.evaluatedAuthorityGeneration,
    required Map<String, FacetTrust> facetTrust,
    required this.scoreProjection,
    required List<String> committedRecordIds,
    required List<String> missingDependencyTargets,
    required List<String> conflictNotes,
    required List<String> unsupportedSemanticRecordIds,
  })  : facetTrust = Map.unmodifiable(facetTrust),
        committedRecordIds = List.unmodifiable(committedRecordIds),
        missingDependencyTargets = List.unmodifiable(missingDependencyTargets),
        conflictNotes = List.unmodifiable(conflictNotes),
        unsupportedSemanticRecordIds =
            List.unmodifiable(unsupportedSemanticRecordIds);

  @override
  final String matchId;
  final int evaluatedAuthorityGeneration;
  final Map<String, FacetTrust> facetTrust;
  final ScoreProjection scoreProjection;
  final List<String> committedRecordIds;
  final List<String> missingDependencyTargets;
  final List<String> conflictNotes;

  /// Committed records with no explicit sporting projection semantics declared.
  final List<String> unsupportedSemanticRecordIds;

  ProjectionTrust trustFor(String facetId) =>
      facetTrust[facetId]?.trust ?? ProjectionTrust.untrusted;

  @override
  bool operator ==(Object other) {
    return other is MatchProjectionState &&
        matchId == other.matchId &&
        evaluatedAuthorityGeneration == other.evaluatedAuthorityGeneration &&
        _mapEquals(facetTrust, other.facetTrust) &&
        scoreProjection == other.scoreProjection &&
        _listEquals(committedRecordIds, other.committedRecordIds) &&
        _listEquals(missingDependencyTargets, other.missingDependencyTargets) &&
        _listEquals(conflictNotes, other.conflictNotes) &&
        _listEquals(
          unsupportedSemanticRecordIds,
          other.unsupportedSemanticRecordIds,
        );
  }

  @override
  int get hashCode => Object.hash(
        matchId,
        evaluatedAuthorityGeneration,
        Object.hashAll(facetTrust.entries),
        scoreProjection,
        Object.hashAll(committedRecordIds),
        Object.hashAll(missingDependencyTargets),
        Object.hashAll(conflictNotes),
        Object.hashAll(unsupportedSemanticRecordIds),
      );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals(Map<String, FacetTrust> a, Map<String, FacetTrust> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
