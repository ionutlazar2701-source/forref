import '../authority.dart';
import '../canonical_record_form.dart';
import '../match_record.dart';
import '../ports.dart';
import '../record_kind.dart';
import '../relationships.dart';
import 'match_projection_state.dart';
import 'effective_goal_resolver.dart';
import 'projection_context.dart';
import 'projection_semantics_resolver.dart';
import 'projection_trust.dart';
import 'score_completeness_proof.dart';
import 'score_projection.dart';
import '../match_team.dart';
import '../semantics/v1_semantic_payload.dart';

/// Rebuilds [MatchProjectionState] from committed records only.
///
/// Ordering authority: `(originDeviceId, originSequence, recordId)`.
/// Never uses transport order, database row order, or [MatchRecord.recordedAt].
final class DeterministicMatchProjector {
  const DeterministicMatchProjector(this.semanticsResolver);

  final ProjectionSemanticsResolver semanticsResolver;

  Future<MatchProjectionState> project(
    MatchMemory memory,
    String matchId,
    ProjectionContext context,
  ) async {
    final fetched = await memory.readCommittedForMatch(matchId);
    return projectRecords(
      matchId: matchId,
      records: fetched,
      context: context,
    );
  }

  MatchProjectionState projectRecords({
    required String matchId,
    required List<MatchRecord> records,
    required ProjectionContext context,
  }) {
    final sorted = [...records]..sort(_deterministicOrder);
    final byId = {for (final record in sorted) record.recordId: record};
    final recordIds = byId.keys.toSet();

    final explicitFacetContributors = <String, Set<String>>{};
    final unsupportedSemanticRecordIds = <String>[];
    final facetCauses = <String, Set<_TrustCause>>{};
    final missingDependencyTargets = <String>[];
    final conflictNotes = <String>[];

    for (final facet in context.trackedFacets) {
      facetCauses[facet] = {};
    }

    for (final record in sorted) {
      final contribution = semanticsResolver.resolve(record);
      if (!contribution.isSupported) {
        unsupportedSemanticRecordIds.add(record.recordId);
        continue;
      }
      for (final facet in contribution.supportedFacets) {
        if (!context.trackedFacets.contains(facet)) continue;
        explicitFacetContributors
            .putIfAbsent(facet, () => {})
            .add(record.recordId);
        facetCauses[facet]!.add(_TrustCause.explicitSemanticSupport);
        if (contribution.missingRequiredRelationship) {
          facetCauses[facet]!.add(_TrustCause.missingDependency);
        }
      }
      final targetId = contribution.requiredTargetRecordId;
      if (targetId != null && !recordIds.contains(targetId)) {
        missingDependencyTargets.add(targetId);
        for (final facet in contribution.supportedFacets) {
          _note(facetCauses, facet, _TrustCause.missingDependency);
        }
        _note(
          facetCauses,
          ProjectionFacet.dependencies,
          _TrustCause.missingDependency,
        );
      } else if (contribution.missingRequiredRelationship) {
        _note(
          facetCauses,
          ProjectionFacet.dependencies,
          _TrustCause.missingDependency,
        );
      }
    }

    if (sorted.isEmpty) {
      _note(facetCauses, ProjectionFacet.coverage, _TrustCause.noCommittedRecords);
    } else {
      _note(facetCauses, ProjectionFacet.coverage, _TrustCause.committedRecordsPresent);
    }

    for (final record in sorted) {
      for (final link in record.relationships) {
        if (link is! CausalDependency) continue;
        if (recordIds.contains(link.targetRecordId)) continue;
        missingDependencyTargets.add(link.targetRecordId);
        final contribution = semanticsResolver.resolve(record);
        if (!contribution.isSupported) {
          _note(
            facetCauses,
            ProjectionFacet.dependencies,
            _TrustCause.missingDependency,
          );
          continue;
        }
        for (final facet in contribution.supportedFacets) {
          _note(facetCauses, facet, _TrustCause.missingDependency);
        }
        _note(
          facetCauses,
          ProjectionFacet.dependencies,
          _TrustCause.missingDependency,
        );
      }
    }

    if (sorted.isNotEmpty && missingDependencyTargets.isEmpty) {
      _note(
        facetCauses,
        ProjectionFacet.dependencies,
        _TrustCause.dependenciesSatisfied,
      );
    }

    _applyAuthorityEvaluation(
      sorted: sorted,
      context: context,
      facetCauses: facetCauses,
      explicitFacetContributors: explicitFacetContributors,
      conflictNotes: conflictNotes,
    );

    _applyCorrectionConflicts(
      sorted: sorted,
      byId: byId,
      facetCauses: facetCauses,
      conflictNotes: conflictNotes,
    );

    var facetTrust = <String, FacetTrust>{
      for (final facet in context.trackedFacets)
        facet: FacetTrust(
          facetId: facet,
          trust: _resolveTrust(
            facet: facet,
            causes: facetCauses[facet] ?? {},
            hasExplicitContributor: explicitFacetContributors.containsKey(facet),
          ),
          reason: _resolveReason(facetCauses[facet] ?? {}, facet),
        ),
    };

    final scoreCauses = facetCauses[ProjectionFacet.score] ?? {};
    final appliesProductionScore = context.scoreCompletenessProof != null ||
        sorted.any((record) => record.payload is GoalPayload);
    final scoreProjection = appliesProductionScore
        ? _deriveScoreProjection(
            matchId: matchId,
            sortedRecords: sorted,
            recordsById: byId,
            context: context,
            scoreAuthorityConflict:
                scoreCauses.contains(_TrustCause.authorityConflict),
            scoreCorrectionConflict:
                scoreCauses.contains(_TrustCause.correctionConflict),
            scoreMissingDependency:
                scoreCauses.contains(_TrustCause.missingDependency),
            unsupportedSemanticRecordIds: unsupportedSemanticRecordIds,
            missingDependencyTargets: missingDependencyTargets.toSet().toList()
              ..sort(),
          )
        : const ScoreUnavailable();

    if (appliesProductionScore &&
        context.trackedFacets.contains(ProjectionFacet.score)) {
      final scoreTrust = switch (scoreProjection) {
        KnownScore() => ProjectionTrust.trusted,
        ScoreConflicted() => ProjectionTrust.conflicted,
        ScoreUnavailable() => ProjectionTrust.untrusted,
      };
      final scoreReason = switch (scoreProjection) {
        KnownScore() =>
          'explicit semantic support with complete non-conflicted evidence',
        ScoreConflicted() => 'contradictory authoritative corrections',
        ScoreUnavailable() => _resolveReason(
            facetCauses[ProjectionFacet.score] ?? {},
            ProjectionFacet.score,
          ) ??
            'score completeness proof not satisfied',
      };
      facetTrust = Map<String, FacetTrust>.from(facetTrust);
      facetTrust[ProjectionFacet.score] = FacetTrust(
        facetId: ProjectionFacet.score,
        trust: scoreTrust,
        reason: scoreReason,
      );
    }

    return MatchProjectionState(
      matchId: matchId,
      evaluatedAuthorityGeneration: context.evaluatedAuthorityGeneration,
      facetTrust: facetTrust,
      scoreProjection: scoreProjection,
      committedRecordIds: [for (final record in sorted) record.recordId],
      missingDependencyTargets: missingDependencyTargets.toSet().toList()
        ..sort(),
      conflictNotes: conflictNotes,
      unsupportedSemanticRecordIds: unsupportedSemanticRecordIds,
    );
  }

  ScoreProjection _deriveScoreProjection({
    required String matchId,
    required List<MatchRecord> sortedRecords,
    required Map<String, MatchRecord> recordsById,
    required ProjectionContext context,
    required bool scoreAuthorityConflict,
    required bool scoreCorrectionConflict,
    required bool scoreMissingDependency,
    required List<String> unsupportedSemanticRecordIds,
    required List<String> missingDependencyTargets,
  }) {
    if (!context.trackedFacets.contains(ProjectionFacet.score)) {
      return const ScoreUnavailable();
    }

    final effective = resolveEffectiveGoals(recordsById: recordsById);
    if (effective is EffectiveGoalConflicted) {
      return const ScoreConflicted();
    }
    if (effective is EffectiveGoalUnavailable) {
      return const ScoreUnavailable();
    }
    final effectiveGoals = (effective as EffectiveGoalSet).goals;

    final proofCheck = validateScoreCompletenessProof(
      matchId: matchId,
      sortedRecords: sortedRecords,
      proof: context.scoreCompletenessProof,
      scoreAuthorityConflict: scoreAuthorityConflict,
      scoreCorrectionConflict: scoreCorrectionConflict,
      scoreMissingDependency: scoreMissingDependency,
      unsupportedSemanticRecordIds: unsupportedSemanticRecordIds,
      missingDependencyTargets: missingDependencyTargets,
    );
    if (proofCheck.conflicted) {
      return const ScoreConflicted();
    }
    if (!proofCheck.ready) {
      return const ScoreUnavailable();
    }

    final tallies = <MatchTeamId, int>{
      for (final team in proofCheck.teamIds) team: 0,
    };
    for (final goal in effectiveGoals) {
      if (!tallies.containsKey(goal.scoringTeamId)) {
        return const ScoreUnavailable();
      }
      tallies[goal.scoringTeamId] = tallies[goal.scoringTeamId]! + 1;
    }
    return KnownScore(tallies);
  }

  static int _deterministicOrder(MatchRecord a, MatchRecord b) {
    final origin = a.originDeviceId.compareTo(b.originDeviceId);
    if (origin != 0) return origin;
    final sequence = a.originSequence.compareTo(b.originSequence);
    if (sequence != 0) return sequence;
    return a.recordId.compareTo(b.recordId);
  }

  void _applyAuthorityEvaluation({
    required List<MatchRecord> sorted,
    required ProjectionContext context,
    required Map<String, Set<_TrustCause>> facetCauses,
    required Map<String, Set<String>> explicitFacetContributors,
    required List<String> conflictNotes,
  }) {
    final principalsAtGeneration = <String>{};
    var sawGeneration = false;

    for (final record in sorted) {
      final authority = record.authorityContext;
      if (authority == null) continue;
      if (authority.scope is! MainRefereeScope) continue;
      final generation = authority.generation?.value;
      if (generation == null) continue;
      if (generation > context.evaluatedAuthorityGeneration) {
        _note(
          facetCauses,
          ProjectionFacet.authority,
          _TrustCause.authorityBeyondBoundary,
        );
        continue;
      }
      if (generation != context.evaluatedAuthorityGeneration) continue;
      sawGeneration = true;
      final principal = authority.principal?.principalId;
      if (principal == null) {
        _note(
          facetCauses,
          ProjectionFacet.authority,
          _TrustCause.missingAuthorityPrincipal,
        );
        continue;
      }
      principalsAtGeneration.add(principal);
    }

    if (principalsAtGeneration.length > 1) {
      conflictNotes.add(
        'same-scope authority conflict at generation '
        '${context.evaluatedAuthorityGeneration}: $principalsAtGeneration',
      );
      _note(
        facetCauses,
        ProjectionFacet.authority,
        _TrustCause.authorityConflict,
      );
      for (final record in sorted) {
        final authority = record.authorityContext;
        if (authority?.generation?.value !=
            context.evaluatedAuthorityGeneration) {
          continue;
        }
        final contribution = semanticsResolver.resolve(record);
        if (!contribution.isSupported) continue;
        for (final facet in contribution.supportedFacets) {
          _note(facetCauses, facet, _TrustCause.authorityConflict);
        }
      }
    } else if (sawGeneration && principalsAtGeneration.length == 1) {
      _note(
        facetCauses,
        ProjectionFacet.authority,
        _TrustCause.authoritySatisfied,
      );
    } else if (sorted.isNotEmpty) {
      _note(
        facetCauses,
        ProjectionFacet.authority,
        _TrustCause.noRecordsAtEvaluatedGeneration,
      );
    }
  }

  void _applyCorrectionConflicts({
    required List<MatchRecord> sorted,
    required Map<String, MatchRecord> byId,
    required Map<String, Set<_TrustCause>> facetCauses,
    required List<String> conflictNotes,
  }) {
    final correctionsByTarget = <String, List<MatchRecord>>{};
    for (final record in sorted) {
      if (record.recordKind != RecordKind.correction &&
          record.recordKind != RecordKind.legalSupersession) {
        continue;
      }
      for (final link in record.relationships) {
        if (link is CorrectionTarget || link is LegalSupersessionTarget) {
          correctionsByTarget
              .putIfAbsent(link.targetRecordId, () => [])
              .add(record);
        }
      }
    }

    for (final entry in correctionsByTarget.entries) {
      final corrections = entry.value;
      if (corrections.length < 2) continue;
      final baseline = corrections.first;
      final contradictory = corrections.skip(1).any(
            (candidate) =>
                !identicalCanonicalRecordContent(baseline, candidate),
          );
      if (!contradictory) continue;

      conflictNotes.add(
        'contradictory corrections for target ${entry.key}',
      );
      final target = byId[entry.key];
      final facets = target == null
          ? [ProjectionFacet.coverage]
          : _supportedFacets(target);
      if (facets.isEmpty) {
        _note(facetCauses, ProjectionFacet.coverage, _TrustCause.correctionConflict);
        continue;
      }
      for (final facet in facets) {
        _note(facetCauses, facet, _TrustCause.correctionConflict);
      }
    }
  }

  List<String> _supportedFacets(MatchRecord record) {
    final contribution = semanticsResolver.resolve(record);
    if (!contribution.isSupported) return const [];
    return contribution.supportedFacets;
  }

  static void _note(
    Map<String, Set<_TrustCause>> facetCauses,
    String facetId,
    _TrustCause cause,
  ) {
    facetCauses.putIfAbsent(facetId, () => {}).add(cause);
  }

  /// Explicit resolution — not enum ordering or numeric severity.
  static ProjectionTrust _resolveTrust({
    required String facet,
    required Set<_TrustCause> causes,
    required bool hasExplicitContributor,
  }) {
    if (causes.contains(_TrustCause.authorityConflict) ||
        causes.contains(_TrustCause.correctionConflict)) {
      return ProjectionTrust.conflicted;
    }

    if (causes.contains(_TrustCause.missingDependency) ||
        causes.contains(_TrustCause.authorityBeyondBoundary) ||
        causes.contains(_TrustCause.missingAuthorityPrincipal) ||
        causes.contains(_TrustCause.noRecordsAtEvaluatedGeneration)) {
      return ProjectionTrust.incomplete;
    }

    if (_isGenericFacet(facet)) {
      if (causes.contains(_TrustCause.noCommittedRecords)) {
        return ProjectionTrust.untrusted;
      }
      if (facet == ProjectionFacet.coverage &&
          causes.contains(_TrustCause.committedRecordsPresent)) {
        return ProjectionTrust.trusted;
      }
      if (facet == ProjectionFacet.dependencies &&
          causes.contains(_TrustCause.dependenciesSatisfied)) {
        return ProjectionTrust.trusted;
      }
      if (facet == ProjectionFacet.authority &&
          causes.contains(_TrustCause.authoritySatisfied)) {
        return ProjectionTrust.trusted;
      }
      return ProjectionTrust.untrusted;
    }

    if (!hasExplicitContributor ||
        !causes.contains(_TrustCause.explicitSemanticSupport)) {
      return ProjectionTrust.untrusted;
    }

    if (causes.contains(_TrustCause.explicitSemanticSupport) &&
        !causes.contains(_TrustCause.missingDependency)) {
      return ProjectionTrust.trusted;
    }

    return ProjectionTrust.untrusted;
  }

  static bool _isGenericFacet(String facet) {
    return facet == ProjectionFacet.coverage ||
        facet == ProjectionFacet.authority ||
        facet == ProjectionFacet.dependencies;
  }

  static String? _resolveReason(Set<_TrustCause> causes, String facet) {
    if (causes.contains(_TrustCause.authorityConflict)) {
      return 'contradictory valid authority';
    }
    if (causes.contains(_TrustCause.correctionConflict)) {
      return 'contradictory authoritative corrections';
    }
    if (causes.contains(_TrustCause.missingDependency)) {
      return 'missing required dependency';
    }
    if (causes.contains(_TrustCause.authorityBeyondBoundary)) {
      return 'authority generation beyond evaluation boundary';
    }
    if (causes.contains(_TrustCause.missingAuthorityPrincipal)) {
      return 'missing authority principal';
    }
    if (causes.contains(_TrustCause.noRecordsAtEvaluatedGeneration)) {
      return 'no records at evaluated authority generation';
    }
    if (causes.contains(_TrustCause.noCommittedRecords)) {
      return 'no committed records';
    }
    if (!_isGenericFacet(facet) &&
        !causes.contains(_TrustCause.explicitSemanticSupport)) {
      return 'no explicit projection semantics declared';
    }
    if (causes.contains(_TrustCause.explicitSemanticSupport)) {
      return 'explicit semantic support with complete non-conflicted evidence';
    }
    return null;
  }
}

enum _TrustCause {
  committedRecordsPresent,
  noCommittedRecords,
  explicitSemanticSupport,
  missingDependency,
  dependenciesSatisfied,
  authorityConflict,
  authorityBeyondBoundary,
  missingAuthorityPrincipal,
  noRecordsAtEvaluatedGeneration,
  authoritySatisfied,
  correctionConflict,
}
