import '../authority.dart';
import '../match_record.dart';
import '../participant/disciplinary_accounting_scope.dart';
import '../participant/identity_confidence.dart';
import '../participant/match_participant_id.dart';
import '../participant/participant_binding.dart';
import '../participant/participant_ref.dart';
import '../participant/participant_status_at_determination.dart';
import '../record_kind.dart';
import '../relationships.dart';
import '../semantics/production_semantics_resolver.dart';
import '../semantics/v1_semantic_payload.dart';
import '../semantics/yellow_card_disciplinary_system_support.dart';
import 'disciplinary_authority_projection.dart';
import 'participant_identity_projection.dart';
import 'projection_semantics_resolver.dart';
import 'projection_trust.dart';
import 'temporal_match_projection.dart';

/// Current legal effect of one immutable historical caution.
enum CautionStandingEffect {
  /// The caution currently contributes to its participant/scope ledger.
  standing,

  /// A later authoritative legal supersession removed its standing effect.
  legallySuperseded,

  /// Available records do not establish a safe current legal effect.
  unresolved,
}

/// Trustworthy answer to "does this participant already have a caution?".
enum PriorCautionState {
  none,
  standing,
  unresolved,
}

/// One participant's disciplinary ledger. Shirt number is never a key.
final class DisciplinaryLedgerKey {
  const DisciplinaryLedgerKey({
    required this.canonicalParticipantId,
    required this.accountingScope,
  });

  final MatchParticipantId canonicalParticipantId;
  final DisciplinaryAccountingScope accountingScope;

  @override
  bool operator ==(Object other) =>
      other is DisciplinaryLedgerKey &&
      canonicalParticipantId == other.canonicalParticipantId &&
      accountingScope == other.accountingScope;

  @override
  int get hashCode => Object.hash(canonicalParticipantId, accountingScope);
}

/// Read-only prior-caution assessment for one participant/scope ledger.
final class PriorCautionAssessment {
  const PriorCautionAssessment({
    required this.state,
    required this.standingCautionCount,
  });

  static const none = PriorCautionAssessment(
    state: PriorCautionState.none,
    standingCautionCount: 0,
  );

  static const unresolved = PriorCautionAssessment(
    state: PriorCautionState.unresolved,
    standingCautionCount: 0,
  );

  final PriorCautionState state;
  final int standingCautionCount;

  bool get hasPriorStandingCaution => state == PriorCautionState.standing;

  /// Advisory sequence awareness only. This does not create dismissal or red.
  bool get nextCautionWouldBeSecond =>
      state == PriorCautionState.standing && standingCautionCount == 1;

  int? get nextStandingOrdinal =>
      state == PriorCautionState.standing ? standingCautionCount + 1 : null;

  @override
  bool operator ==(Object other) =>
      other is PriorCautionAssessment &&
      state == other.state &&
      standingCautionCount == other.standingCautionCount;

  @override
  int get hashCode => Object.hash(state, standingCautionCount);
}

/// One immutable YELLOW_CARD in historical disciplinary history.
final class ProjectedHistoricalCaution {
  const ProjectedHistoricalCaution({
    required this.recordId,
    required this.captureIntentId,
    required this.participantRefAtDetermination,
    required this.participantStatusAtDetermination,
    required this.accountingScope,
    required this.identityConfidence,
    required this.standingEffect,
    this.canonicalParticipantId,
    this.reason,
    this.standingOrdinal,
  });

  final String recordId;
  final String captureIntentId;
  final ParticipantRef participantRefAtDetermination;
  final ParticipantStatusAtDetermination participantStatusAtDetermination;
  final DisciplinaryAccountingScope accountingScope;
  final MatchParticipantId? canonicalParticipantId;
  final IdentityConfidence identityConfidence;
  final String? reason;
  final CautionStandingEffect standingEffect;

  /// Current ordinal in the canonical participant/scope standing ledger.
  ///
  /// Null when this historical caution does not currently stand.
  final int? standingOrdinal;

  bool get countsAsStanding =>
      standingEffect == CautionStandingEffect.standing &&
      canonicalParticipantId != null &&
      standingOrdinal != null;

  bool get hasPriorStandingCaution => countsAsStanding && standingOrdinal! > 1;

  /// Advisory sequence awareness. Never automatic dismissal authority.
  bool get isSecondStandingCaution => countsAsStanding && standingOrdinal == 2;
}

enum UnresolvedDisciplinaryConsequenceCode {
  unsupportedYellowCardSemantic,
  authorityInvalid,
  authorityConflict,
  participantIdentityUnresolved,
  participantIdentityConflicted,
  disciplinarySystemUnsupported,
  disciplinarySystemUnresolved,
  accountingScopeUnresolved,
  correctionLegalEffectUnresolved,
  duplicateCaptureIntent,
  missingLegalEffectTarget,
  mixedMatchRecords,
}

/// Typed reason a standing or prior-caution answer cannot be trusted.
final class UnresolvedDisciplinaryConsequence {
  const UnresolvedDisciplinaryConsequence({
    required this.code,
    this.recordId,
    this.targetRecordId,
    this.canonicalParticipantId,
    this.accountingScope,
  });

  final UnresolvedDisciplinaryConsequenceCode code;
  final String? recordId;
  final String? targetRecordId;
  final MatchParticipantId? canonicalParticipantId;
  final DisciplinaryAccountingScope? accountingScope;
}

/// Disposable disciplinary read model rebuilt only from immutable Match Memory.
///
/// It preserves every supported authoritative YELLOW_CARD in history, while
/// standing ledgers fail closed on unsupported identity, scope, system,
/// authority, idempotency, or legal-effect evidence. It never stores a mutable
/// count and never creates dismissal authority.
final class DisciplinaryMatchProjection {
  DisciplinaryMatchProjection._({
    required this.historicalCautions,
    required this.standingCautions,
    required this.priorCautionState,
    required this.participantIdentityTrust,
    required this.disciplinaryFacetTrust,
    required this.disciplinaryAccountingScope,
    required this.unresolvedConsequences,
    required ParticipantIdentityProjection identityProjection,
    required bool hasGlobalUnresolvedConsequence,
  })  : _identityProjection = identityProjection,
        _hasGlobalUnresolvedConsequence = hasGlobalUnresolvedConsequence;

  final List<ProjectedHistoricalCaution> historicalCautions;
  final List<ProjectedHistoricalCaution> standingCautions;
  final Map<DisciplinaryLedgerKey, PriorCautionAssessment> priorCautionState;
  final ProjectionTrust participantIdentityTrust;
  final ProjectionTrust disciplinaryFacetTrust;
  final DisciplinaryAccountingScope disciplinaryAccountingScope;
  final List<UnresolvedDisciplinaryConsequence> unresolvedConsequences;

  final ParticipantIdentityProjection _identityProjection;
  final bool _hasGlobalUnresolvedConsequence;

  /// Answers prior-caution state after final identity reconciliation.
  ///
  /// A missing map entry is `none` only when this participant and the relevant
  /// disciplinary evidence are trustworthy. Otherwise the answer is unresolved.
  PriorCautionAssessment priorCautionStateFor({
    required MatchParticipantId participantId,
    required DisciplinaryAccountingScope accountingScope,
  }) {
    if (accountingScope == DisciplinaryAccountingScope.unresolved) {
      return PriorCautionAssessment.unresolved;
    }
    final identity = _identityFor(_identityProjection, participantId);
    if (!_identitySufficient(identity)) {
      return PriorCautionAssessment.unresolved;
    }
    final key = DisciplinaryLedgerKey(
      canonicalParticipantId: identity!.canonicalId,
      accountingScope: accountingScope,
    );
    final known = priorCautionState[key];
    if (known != null) return known;
    if (_hasGlobalUnresolvedConsequence) {
      return PriorCautionAssessment.unresolved;
    }
    return PriorCautionAssessment.none;
  }

  static DisciplinaryMatchProjection derive({
    required List<MatchRecord> records,
    required int evaluatedAuthorityGeneration,
    CompetitionRulesContext? competitionRules,
    ProjectionSemanticsResolver? semanticsResolver,
  }) {
    final resolver = semanticsResolver ?? ProductionSemanticsResolver();
    final ordered = [...records]..sort(deterministicRecordOrder);
    final identities = ParticipantIdentityProjection.derive(records: ordered);
    final authority = DisciplinaryAuthorityProjection.derive(
      records: ordered,
      competitionRules: competitionRules,
    );
    final unresolved = <UnresolvedDisciplinaryConsequence>[];
    final candidates = <_CautionCandidate>[];
    var identityTrust = switch (identities.overallConfidence) {
      IdentityConfidence.resolved ||
      IdentityConfidence.provisional =>
        ProjectionTrust.trusted,
      IdentityConfidence.ambiguous => ProjectionTrust.incomplete,
      IdentityConfidence.conflicted => ProjectionTrust.conflicted,
    };
    var disciplinaryTrust = ProjectionTrust.trusted;
    var hasGlobalUnresolved = false;

    final matchIds = {for (final record in ordered) record.matchId};
    if (matchIds.length > 1) {
      unresolved.add(
        const UnresolvedDisciplinaryConsequence(
          code: UnresolvedDisciplinaryConsequenceCode.mixedMatchRecords,
        ),
      );
      disciplinaryTrust = ProjectionTrust.conflicted;
      hasGlobalUnresolved = true;
    }

    for (final record in ordered) {
      final payload = record.payload;
      if (payload is! YellowCardPayload) continue;
      final contribution = resolver.resolve(record);
      if (!contribution.isSupported) {
        unresolved.add(
          UnresolvedDisciplinaryConsequence(
            code: UnresolvedDisciplinaryConsequenceCode
                .unsupportedYellowCardSemantic,
            recordId: record.recordId,
            accountingScope: payload.disciplinaryAccountingScope,
          ),
        );
        disciplinaryTrust = _lessTrusted(
          disciplinaryTrust,
          ProjectionTrust.incomplete,
        );
        continue;
      }

      final projectedIdentity = _identityFor(
        identities,
        payload.participantRef.matchParticipantId,
      );
      final candidate = _CautionCandidate(
        record: record,
        payload: payload,
        identity: projectedIdentity,
      );
      candidates.add(candidate);

      final authorityCode = _authorityProblem(
        record,
        evaluatedAuthorityGeneration,
      );
      if (authorityCode != null) {
        candidate.unresolved = true;
        unresolved.add(
          UnresolvedDisciplinaryConsequence(
            code: authorityCode,
            recordId: record.recordId,
            canonicalParticipantId: projectedIdentity?.canonicalId,
            accountingScope: payload.disciplinaryAccountingScope,
          ),
        );
        disciplinaryTrust = _lessTrusted(
          disciplinaryTrust,
          ProjectionTrust.incomplete,
        );
      }

      if (!_identitySufficient(projectedIdentity)) {
        candidate.unresolved = true;
        final conflicted =
            projectedIdentity?.confidence == IdentityConfidence.conflicted;
        unresolved.add(
          UnresolvedDisciplinaryConsequence(
            code: conflicted
                ? UnresolvedDisciplinaryConsequenceCode
                    .participantIdentityConflicted
                : UnresolvedDisciplinaryConsequenceCode
                    .participantIdentityUnresolved,
            recordId: record.recordId,
            canonicalParticipantId: projectedIdentity?.canonicalId,
            accountingScope: payload.disciplinaryAccountingScope,
          ),
        );
        identityTrust = _lessTrusted(
          identityTrust,
          conflicted ? ProjectionTrust.conflicted : ProjectionTrust.incomplete,
        );
        disciplinaryTrust = _lessTrusted(
          disciplinaryTrust,
          conflicted ? ProjectionTrust.conflicted : ProjectionTrust.incomplete,
        );
      }

      final system = YellowCardDisciplinarySystemSupportGate.assess(
        payload.competitionRulesContext,
      );
      switch (system) {
        case YellowCardDisciplinarySystemSupport.supported:
          break;
        case YellowCardDisciplinarySystemSupport.unsupportedModifiedSystem:
          candidate.unresolved = true;
          unresolved.add(
            UnresolvedDisciplinaryConsequence(
              code: UnresolvedDisciplinaryConsequenceCode
                  .disciplinarySystemUnsupported,
              recordId: record.recordId,
              canonicalParticipantId: projectedIdentity?.canonicalId,
              accountingScope: payload.disciplinaryAccountingScope,
            ),
          );
          disciplinaryTrust = _lessTrusted(
            disciplinaryTrust,
            ProjectionTrust.incomplete,
          );
        case YellowCardDisciplinarySystemSupport.unresolved:
          candidate.unresolved = true;
          unresolved.add(
            UnresolvedDisciplinaryConsequence(
              code: UnresolvedDisciplinaryConsequenceCode
                  .disciplinarySystemUnresolved,
              recordId: record.recordId,
              canonicalParticipantId: projectedIdentity?.canonicalId,
              accountingScope: payload.disciplinaryAccountingScope,
            ),
          );
          disciplinaryTrust = _lessTrusted(
            disciplinaryTrust,
            ProjectionTrust.incomplete,
          );
      }

      if (payload.disciplinaryAccountingScope ==
          DisciplinaryAccountingScope.unresolved) {
        candidate.unresolved = true;
        unresolved.add(
          UnresolvedDisciplinaryConsequence(
            code:
                UnresolvedDisciplinaryConsequenceCode.accountingScopeUnresolved,
            recordId: record.recordId,
            canonicalParticipantId: projectedIdentity?.canonicalId,
            accountingScope: payload.disciplinaryAccountingScope,
          ),
        );
        disciplinaryTrust = _lessTrusted(
          disciplinaryTrust,
          ProjectionTrust.incomplete,
        );
      }
    }

    final candidatesById = {
      for (final candidate in candidates) candidate.record.recordId: candidate,
    };
    final principalsByGeneration = <int, Set<String>>{};
    for (final candidate in candidates) {
      final context = candidate.record.authorityContext;
      final generation = context?.generation?.value;
      final principal = context?.principal?.principalId;
      if (generation == null || principal == null || principal.isEmpty) {
        continue;
      }
      principalsByGeneration
          .putIfAbsent(generation, () => <String>{})
          .add(principal);
    }
    for (final entry in principalsByGeneration.entries) {
      if (entry.value.length < 2) continue;
      disciplinaryTrust = ProjectionTrust.conflicted;
      for (final candidate in candidates) {
        if (candidate.record.authorityContext?.generation?.value != entry.key) {
          continue;
        }
        candidate.unresolved = true;
        unresolved.add(
          UnresolvedDisciplinaryConsequence(
            code: UnresolvedDisciplinaryConsequenceCode.authorityConflict,
            recordId: candidate.record.recordId,
            canonicalParticipantId: candidate.identity?.canonicalId,
            accountingScope: candidate.payload.disciplinaryAccountingScope,
          ),
        );
      }
    }

    final byIntent = <String, List<_CautionCandidate>>{};
    for (final candidate in candidates) {
      byIntent
          .putIfAbsent(candidate.payload.captureIntentId, () => [])
          .add(candidate);
    }
    for (final group in byIntent.values) {
      if (group.length < 2) continue;
      final conflict = group.skip(1).any(
            (candidate) =>
                !_sameCaptureContent(group.first.payload, candidate.payload),
          );
      disciplinaryTrust = _lessTrusted(
        disciplinaryTrust,
        conflict ? ProjectionTrust.conflicted : ProjectionTrust.incomplete,
      );
      for (final candidate in group) {
        candidate.unresolved = true;
        unresolved.add(
          UnresolvedDisciplinaryConsequence(
            code: UnresolvedDisciplinaryConsequenceCode.duplicateCaptureIntent,
            recordId: candidate.record.recordId,
            canonicalParticipantId: candidate.identity?.canonicalId,
            accountingScope: candidate.payload.disciplinaryAccountingScope,
          ),
        );
      }
    }

    for (final record in ordered) {
      if (record.recordKind == RecordKind.legalSupersession &&
          record.payload is LegalSupersessionPayload &&
          resolver.resolve(record).isSupported) {
        final links =
            record.relationships.whereType<LegalSupersessionTarget>().toList();
        if (links.isEmpty) {
          unresolved.add(
            UnresolvedDisciplinaryConsequence(
              code: UnresolvedDisciplinaryConsequenceCode
                  .missingLegalEffectTarget,
              recordId: record.recordId,
            ),
          );
          disciplinaryTrust = _lessTrusted(
            disciplinaryTrust,
            ProjectionTrust.incomplete,
          );
          hasGlobalUnresolved = true;
          continue;
        }
        final authorityCode = _authorityProblem(
          record,
          evaluatedAuthorityGeneration,
        );
        for (final link in links) {
          final target = candidatesById[link.targetRecordId];
          if (target == null) {
            unresolved.add(
              UnresolvedDisciplinaryConsequence(
                code: UnresolvedDisciplinaryConsequenceCode
                    .missingLegalEffectTarget,
                recordId: record.recordId,
                targetRecordId: link.targetRecordId,
              ),
            );
            disciplinaryTrust = _lessTrusted(
              disciplinaryTrust,
              ProjectionTrust.incomplete,
            );
            hasGlobalUnresolved = true;
            continue;
          }
          if (authorityCode == null) {
            target.legallySuperseded = true;
            target.unresolved = false;
            unresolved.removeWhere(
              (item) =>
                  item.code ==
                      UnresolvedDisciplinaryConsequenceCode
                          .correctionLegalEffectUnresolved &&
                  item.targetRecordId == target.record.recordId,
            );
          } else {
            target.unresolved = true;
            unresolved.add(
              UnresolvedDisciplinaryConsequence(
                code: authorityCode,
                recordId: record.recordId,
                targetRecordId: target.record.recordId,
                canonicalParticipantId: target.identity?.canonicalId,
                accountingScope: target.payload.disciplinaryAccountingScope,
              ),
            );
            disciplinaryTrust = _lessTrusted(
              disciplinaryTrust,
              ProjectionTrust.incomplete,
            );
          }
        }
        continue;
      }

      if (record.recordKind != RecordKind.correction ||
          record.payload is! CorrectionPayload ||
          !resolver.resolve(record).isSupported) {
        continue;
      }
      for (final link in record.relationships.whereType<CorrectionTarget>()) {
        final target = candidatesById[link.targetRecordId];
        if (target == null || target.legallySuperseded) continue;
        target.unresolved = true;
        unresolved.add(
          UnresolvedDisciplinaryConsequence(
            code: UnresolvedDisciplinaryConsequenceCode
                .correctionLegalEffectUnresolved,
            recordId: record.recordId,
            targetRecordId: target.record.recordId,
            canonicalParticipantId: target.identity?.canonicalId,
            accountingScope: target.payload.disciplinaryAccountingScope,
          ),
        );
        disciplinaryTrust = _lessTrusted(
          disciplinaryTrust,
          ProjectionTrust.incomplete,
        );
      }
    }

    final ordinals = <DisciplinaryLedgerKey, int>{};
    final historical = <ProjectedHistoricalCaution>[];
    final standing = <ProjectedHistoricalCaution>[];
    for (final candidate in candidates) {
      int? ordinal;
      final canonicalId = candidate.identity?.canonicalId;
      if (!candidate.legallySuperseded &&
          !candidate.unresolved &&
          canonicalId != null) {
        final key = DisciplinaryLedgerKey(
          canonicalParticipantId: canonicalId,
          accountingScope: candidate.payload.disciplinaryAccountingScope,
        );
        ordinal = (ordinals[key] ?? 0) + 1;
        ordinals[key] = ordinal;
      }
      final projected = candidate.project(standingOrdinal: ordinal);
      historical.add(projected);
      if (projected.countsAsStanding) standing.add(projected);
    }

    final prior = <DisciplinaryLedgerKey, PriorCautionAssessment>{
      for (final entry in ordinals.entries)
        entry.key: PriorCautionAssessment(
          state: PriorCautionState.standing,
          standingCautionCount: entry.value,
        ),
    };
    for (final consequence in unresolved) {
      final participantId = consequence.canonicalParticipantId;
      final scope = consequence.accountingScope;
      if (participantId == null ||
          scope == null ||
          scope == DisciplinaryAccountingScope.unresolved) {
        hasGlobalUnresolved = true;
        continue;
      }
      prior[DisciplinaryLedgerKey(
        canonicalParticipantId: participantId,
        accountingScope: scope,
      )] = PriorCautionAssessment.unresolved;
    }
    if (unresolved.isEmpty) {
      disciplinaryTrust = ProjectionTrust.trusted;
    }

    return DisciplinaryMatchProjection._(
      historicalCautions: List.unmodifiable(historical),
      standingCautions: List.unmodifiable(standing),
      priorCautionState: Map.unmodifiable(prior),
      participantIdentityTrust: identityTrust,
      disciplinaryFacetTrust: disciplinaryTrust,
      disciplinaryAccountingScope: authority.accountingScope,
      unresolvedConsequences: List.unmodifiable(unresolved),
      identityProjection: identities,
      hasGlobalUnresolvedConsequence: hasGlobalUnresolved,
    );
  }
}

final class _CautionCandidate {
  _CautionCandidate({
    required this.record,
    required this.payload,
    required this.identity,
  });

  final MatchRecord record;
  final YellowCardPayload payload;
  final ProjectedParticipantIdentity? identity;
  bool legallySuperseded = false;
  bool unresolved = false;

  ProjectedHistoricalCaution project({required int? standingOrdinal}) {
    return ProjectedHistoricalCaution(
      recordId: record.recordId,
      captureIntentId: payload.captureIntentId,
      participantRefAtDetermination: payload.participantRef,
      participantStatusAtDetermination:
          payload.participantStatusAtDetermination,
      accountingScope: payload.disciplinaryAccountingScope,
      canonicalParticipantId: identity?.canonicalId,
      identityConfidence:
          identity?.confidence ?? IdentityConfidence.provisional,
      reason: payload.reason,
      standingEffect: legallySuperseded
          ? CautionStandingEffect.legallySuperseded
          : unresolved
              ? CautionStandingEffect.unresolved
              : CautionStandingEffect.standing,
      standingOrdinal: standingOrdinal,
    );
  }
}

ProjectedParticipantIdentity? _identityFor(
  ParticipantIdentityProjection projection,
  MatchParticipantId participantId,
) {
  final direct = projection[participantId];
  if (direct != null) return direct;
  for (final identity in projection.participantsByRegisteredId.values) {
    if (identity.canonicalId == participantId) return identity;
  }
  return null;
}

bool _identitySufficient(ProjectedParticipantIdentity? identity) {
  if (identity == null || identity.registrationRecordId == null) return false;
  return switch (identity.confidence) {
    IdentityConfidence.resolved => true,
    IdentityConfidence.provisional =>
      identity.binding is FreeformDescriptorBinding &&
          (identity.binding as FreeformDescriptorBinding)
              .descriptor
              .trim()
              .isNotEmpty,
    IdentityConfidence.ambiguous || IdentityConfidence.conflicted => false,
  };
}

UnresolvedDisciplinaryConsequenceCode? _authorityProblem(
  MatchRecord record,
  int evaluatedAuthorityGeneration,
) {
  final authority = record.authorityContext;
  if (authority?.scope is! MainRefereeScope ||
      authority?.principal?.principalId.trim().isEmpty != false ||
      authority?.generation?.value == null ||
      authority!.generation!.value > evaluatedAuthorityGeneration) {
    return UnresolvedDisciplinaryConsequenceCode.authorityInvalid;
  }
  return null;
}

bool _sameCaptureContent(YellowCardPayload left, YellowCardPayload right) {
  return left.participantRef == right.participantRef &&
      left.participantStatusAtDetermination ==
          right.participantStatusAtDetermination &&
      left.disciplinaryAccountingScope == right.disciplinaryAccountingScope;
}

ProjectionTrust _lessTrusted(
  ProjectionTrust current,
  ProjectionTrust candidate,
) {
  if (current == ProjectionTrust.conflicted ||
      candidate == ProjectionTrust.conflicted) {
    return ProjectionTrust.conflicted;
  }
  if (current == ProjectionTrust.incomplete ||
      candidate == ProjectionTrust.incomplete) {
    return ProjectionTrust.incomplete;
  }
  if (current == ProjectionTrust.untrusted ||
      candidate == ProjectionTrust.untrusted) {
    return ProjectionTrust.untrusted;
  }
  return ProjectionTrust.trusted;
}
