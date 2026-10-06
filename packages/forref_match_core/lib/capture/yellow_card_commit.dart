import '../authority.dart';
import '../integrity.dart';
import '../match_record.dart';
import '../participant/disciplinary_accounting_scope.dart';
import '../participant/identity_confidence.dart';
import '../participant/participant_binding.dart';
import '../participant/participant_ref.dart';
import '../participant/participant_status_at_determination.dart';
import '../ports.dart';
import '../projection/disciplinary_authority_projection.dart';
import '../projection/participant_identity_projection.dart';
import '../record_kind.dart';
import '../semantics/v1_semantic_payload.dart';
import '../semantics/yellow_card_disciplinary_system_support.dart';
import '../temporal.dart';
import 'authoritative_record_builder.dart';
import 'capture_context.dart';

/// One administered caution presented for authoritative commit.
///
/// This is not a decision to caution, a pending caution, or a generic capture.
/// The typed [YellowCardPayload] is built only after admission passes.
final class CommitYellowCardCommand {
  const CommitYellowCardCommand({
    required this.context,
    required this.participantRef,
    required this.participantStatusAtDetermination,
    required this.disciplinaryAccountingScope,
    required this.captureIntentId,
    this.reason,
    this.temporalContext,
    this.recordedAt,
  });

  final CaptureContext context;
  final ParticipantRef participantRef;
  final ParticipantStatusAtDetermination participantStatusAtDetermination;
  final DisciplinaryAccountingScope disciplinaryAccountingScope;
  final String captureIntentId;
  final String? reason;

  /// Trusted temporal evidence when the capture device has it.
  ///
  /// Null, or a context with no evidence ids, is explicit temporal uncertainty.
  /// An exact playing minute is not required.
  final TemporalContext? temporalContext;
  final DateTime? recordedAt;
}

/// Typed failure for an authoritative yellow-card commit.
///
/// These names are the domain API. Persistence exceptions are not exposed.
enum YellowCardCommitFailure {
  cardAuthorityClosedOrNotOpen,
  participantIdentityUnresolvedOrConflicted,
  unsupportedDisciplinarySystem,
  disciplinarySystemUnresolved,
  disciplinaryAccountingScopeUnresolved,
  authorityInvalid,
  idempotencyConflict,
  durableCommitFailure,
}

/// Outcome of [YellowCardCommitter.commitYellowCard].
sealed class YellowCardCommitResult {
  const YellowCardCommitResult();

  /// True only after adapter D1 success under the software
  /// [DurableCommitPort] contract, or recovery of a record that already
  /// completed that boundary. This is the Saved acknowledgement boundary.
  ///
  /// This does not claim platform or power-loss D1 certification.
  bool get ackEligible;
}

/// ACK-eligible Saved result. The record is already in Match Memory.
final class YellowCardSaved extends YellowCardCommitResult {
  const YellowCardSaved({
    required this.record,
    required this.recoveredExisting,
  });

  final MatchRecord record;

  /// True when [captureIntentId] was already bound and this call did not append.
  final bool recoveredExisting;

  @override
  bool get ackEligible => true;
}

/// Admission or durability rejection. Not Saved.
final class YellowCardCommitRejected extends YellowCardCommitResult {
  const YellowCardCommitRejected(this.failure);

  final YellowCardCommitFailure failure;

  @override
  bool get ackEligible => false;
}

/// Admission of one administered caution before any Match Record is built.
///
/// Idempotency is applied by [YellowCardCommitter] before this assessment so
/// a replay of an already committed intent is not re-admitted.
YellowCardCommitFailure? assessYellowCardAdmission({
  required CommitYellowCardCommand command,
  required List<MatchRecord> records,
}) {
  final authority = _assessAuthority(command.context, records);
  if (authority != null) return authority;

  final projection = DisciplinaryAuthorityProjection.derive(
    records: records,
    competitionRules: command.context.competitionRulesContext,
  );
  if (!projection.cardDisplayAuthorityOpen) {
    return YellowCardCommitFailure.cardAuthorityClosedOrNotOpen;
  }

  final identity = _assessParticipant(command, records);
  if (identity != null) return identity;

  final system = _assessDisciplinarySystem(command);
  if (system != null) return system;

  return _assessAccountingScope(command, projection);
}

/// Current MAIN_REFEREE generation required for a new authoritative caution.
///
/// A generation older than one already committed for this match is stale.
/// A different principal already writing at the command generation conflicts.
/// Forward generation on a new intent remains available to the capture device.
YellowCardCommitFailure? _assessAuthority(
  CaptureContext context,
  List<MatchRecord> records,
) {
  if (context.authorityScope is! MainRefereeScope) {
    return YellowCardCommitFailure.authorityInvalid;
  }
  if (context.authorityPrincipalId.trim().isEmpty) {
    return YellowCardCommitFailure.authorityInvalid;
  }
  if (context.authorityGeneration != context.projectionAuthorityGeneration) {
    return YellowCardCommitFailure.authorityInvalid;
  }

  var highest = 0;
  final principalsAtGeneration = <String>{};
  for (final record in records) {
    final authority = record.authorityContext;
    if (authority?.scope is! MainRefereeScope) continue;
    final generation = authority?.generation?.value;
    if (generation == null) continue;
    if (generation > highest) highest = generation;
    if (generation == context.authorityGeneration) {
      final principal = authority?.principal?.principalId;
      if (principal != null && principal.isNotEmpty) {
        principalsAtGeneration.add(principal);
      }
    }
  }
  if (highest > 0 && context.authorityGeneration < highest) {
    return YellowCardCommitFailure.authorityInvalid;
  }
  if (principalsAtGeneration.any((id) => id != context.authorityPrincipalId)) {
    return YellowCardCommitFailure.authorityInvalid;
  }
  return null;
}

/// Resolves [ParticipantRef] through [ParticipantIdentityProjection].
///
/// Provisional identity is admissible only when the foundation has already
/// durably registered that [MatchParticipantId] and bound it with a free-form
/// descriptor. Ambiguous and conflicted identities are rejected. Missing ids
/// are rejected. This gate does not merge identities.
YellowCardCommitFailure? _assessParticipant(
  CommitYellowCardCommand command,
  List<MatchRecord> records,
) {
  final projection = ParticipantIdentityProjection.derive(records: records);
  final identity = _identityFor(projection, command.participantRef);
  if (identity == null) {
    return YellowCardCommitFailure.participantIdentityUnresolvedOrConflicted;
  }
  if (!_refMatchesProjected(command.participantRef, identity)) {
    return YellowCardCommitFailure.participantIdentityUnresolvedOrConflicted;
  }

  switch (identity.confidence) {
    case IdentityConfidence.resolved:
      return null;
    case IdentityConfidence.provisional:
      final durable = identity.registrationRecordId != null &&
          identity.registeredId.value.isNotEmpty;
      final binding = identity.binding;
      final sufficientlyBound = binding is FreeformDescriptorBinding &&
          binding.descriptor.trim().isNotEmpty;
      if (durable && sufficientlyBound) return null;
      return YellowCardCommitFailure.participantIdentityUnresolvedOrConflicted;
    case IdentityConfidence.ambiguous:
    case IdentityConfidence.conflicted:
      return YellowCardCommitFailure.participantIdentityUnresolvedOrConflicted;
  }
}

ProjectedParticipantIdentity? _identityFor(
  ParticipantIdentityProjection projection,
  ParticipantRef ref,
) {
  final direct = projection[ref.matchParticipantId];
  if (direct != null) return direct;
  for (final identity in projection.participantsByRegisteredId.values) {
    if (identity.canonicalId == ref.matchParticipantId) return identity;
  }
  return null;
}

bool _refMatchesProjected(
  ParticipantRef ref,
  ProjectedParticipantIdentity identity,
) {
  final idMatches = ref.matchParticipantId == identity.registeredId ||
      ref.matchParticipantId == identity.canonicalId;
  return idMatches &&
      ref.teamSide == identity.teamSide &&
      ref.binding == identity.binding;
}

YellowCardCommitFailure? _assessDisciplinarySystem(
  CommitYellowCardCommand command,
) {
  final support = YellowCardDisciplinarySystemSupportGate.assess(
    command.context.competitionRulesContext,
  );
  return switch (support) {
    YellowCardDisciplinarySystemSupport.supported => null,
    YellowCardDisciplinarySystemSupport.unsupportedModifiedSystem =>
      YellowCardCommitFailure.unsupportedDisciplinarySystem,
    YellowCardDisciplinarySystemSupport.unresolved =>
      YellowCardCommitFailure.disciplinarySystemUnresolved,
  };
}

/// Accepts only an explicit scope that matches the trusted projection.
///
/// [DisciplinaryAccountingScope.unresolved] is never a commit scope.
/// MATCH and SHOOTOUT are not interchangeable.
YellowCardCommitFailure? _assessAccountingScope(
  CommitYellowCardCommand command,
  DisciplinaryAuthorityProjection projection,
) {
  final declared = command.disciplinaryAccountingScope;
  final trusted = projection.accountingScope;
  if (declared == DisciplinaryAccountingScope.unresolved ||
      trusted == DisciplinaryAccountingScope.unresolved ||
      declared != trusted) {
    return YellowCardCommitFailure.disciplinaryAccountingScopeUnresolved;
  }
  return null;
}

/// Binds a caution to temporal evidence when the caller has it.
///
/// Evidence ids are stored as references. They are not converted into a
/// playing minute. When no evidence id is available, the record carries
/// explicit temporal uncertainty instead of a fabricated minute.
TemporalContext bindYellowCardTemporalEvidence(
    CommitYellowCardCommand command) {
  final supplied = command.temporalContext;
  if (supplied != null && supplied.evidenceIds.isNotEmpty) {
    return TemporalContext(
      evidenceIds: supplied.evidenceIds,
      domainClockPolicyVersion: supplied.domainClockPolicyVersion ??
          command.context.domainContractVersion?.value,
      explicitUncertainty: supplied.explicitUncertainty,
    );
  }
  return TemporalContext(
    domainClockPolicyVersion: supplied?.domainClockPolicyVersion ??
        command.context.domainContractVersion?.value,
    explicitUncertainty: true,
  );
}

/// One capture intent binds at most one authoritative YELLOW_CARD.
///
/// Conflict identity is limited to minimum authoritative caution content:
/// participant, status-at-determination, and accounting scope.
///
/// Current authority, competition rules, lifecycle state, timestamp, and
/// temporal evidence are external admission/evidence context. They cannot
/// retroactively conflict with a record that already completed D1.
///
/// Reason is optional enrichment, not minimum caution existence. A reason-only
/// retry recovers the original immutable record; later changes belong in a
/// future correction/enrichment path and never mutate this record.
bool sameYellowCardSportingIdentity(
  YellowCardPayload committed,
  CommitYellowCardCommand command,
) {
  return committed.participantRef == command.participantRef &&
      committed.participantStatusAtDetermination ==
          command.participantStatusAtDetermination &&
      committed.disciplinaryAccountingScope ==
          command.disciplinaryAccountingScope;
}

MatchRecord? yellowCardForCaptureIntent(
  List<MatchRecord> records,
  String captureIntentId,
) {
  for (final record in records) {
    final payload = record.payload;
    if (payload is YellowCardPayload &&
        payload.captureIntentId == captureIntentId) {
      return record;
    }
  }
  return null;
}

const _recoverPrefix = 'YELLOW_CARD_INTENT_RECOVER:';
const _conflictToken = 'YELLOW_CARD_INTENT_CONFLICT';
const _admissionPrefix = 'YELLOW_CARD_ADMISSION:';

/// Authoritative YELLOW_CARD commit.
///
/// Order: validate, build the immutable record, durable commit, then ACK.
/// A failed admission does not allocate an origin sequence. A replay of a
/// bound [captureIntentId] returns the committed record and does not allocate
/// another sequence. D1 failure is not Saved.
final class YellowCardCommitter {
  const YellowCardCommitter({
    required this.originCommit,
    required this.memory,
    required this.recordBuilder,
  });

  final AuthoritativeOriginCommitPort originCommit;
  final MatchMemory memory;
  final AuthoritativeRecordBuilder recordBuilder;

  Future<YellowCardCommitResult> commitYellowCard(
    CommitYellowCardCommand command,
  ) async {
    if (command.captureIntentId.isEmpty) {
      throw ArgumentError.value(
        command.captureIntentId,
        'captureIntentId',
        'YELLOW_CARD requires a capture intent',
      );
    }

    final preview = await memory.readCommittedForMatch(command.context.matchId);
    final existing =
        yellowCardForCaptureIntent(preview, command.captureIntentId);
    if (existing != null) {
      return _replay(existing, command);
    }

    final admission = assessYellowCardAdmission(
      command: command,
      records: preview,
    );
    if (admission != null) {
      return YellowCardCommitRejected(admission);
    }

    final request = recordBuilder.build(
      context: command.context,
      recordKind: RecordKind.humanDetermination,
      payload: YellowCardPayload(
        participantRef: command.participantRef,
        participantStatusAtDetermination:
            command.participantStatusAtDetermination,
        disciplinaryAccountingScope: command.disciplinaryAccountingScope,
        captureIntentId: command.captureIntentId,
        reason: command.reason,
        domainContractVersion: command.context.domainContractVersion,
        competitionRulesContext: command.context.competitionRulesContext,
      ),
      integrity: const IntegrityMetadata(),
      temporalContext: bindYellowCardTemporalEvidence(command),
      recordedAt: command.recordedAt,
    );

    final result = await originCommit.commitAtNextOriginSequence(
      request,
      rejectCommitted: (records) {
        final prior =
            yellowCardForCaptureIntent(records, command.captureIntentId);
        if (prior != null) {
          final payload = prior.payload;
          if (payload is YellowCardPayload &&
              sameYellowCardSportingIdentity(payload, command)) {
            return '$_recoverPrefix${prior.recordId}';
          }
          return _conflictToken;
        }
        final blocked = assessYellowCardAdmission(
          command: command,
          records: records,
        );
        if (blocked != null) return '$_admissionPrefix${blocked.name}';
        return null;
      },
    );

    switch (result) {
      case DurableCommitSuccess():
        final committed = await memory.getById(result.committedRecordId);
        if (committed == null || committed.payload is! YellowCardPayload) {
          return const YellowCardCommitRejected(
            YellowCardCommitFailure.durableCommitFailure,
          );
        }
        return YellowCardSaved(record: committed, recoveredExisting: false);
      case DurableCommitFailure():
        return _mapDurableFailure(result);
    }
  }

  YellowCardCommitResult _replay(
    MatchRecord existing,
    CommitYellowCardCommand command,
  ) {
    final payload = existing.payload;
    if (payload is! YellowCardPayload ||
        !sameYellowCardSportingIdentity(payload, command)) {
      return const YellowCardCommitRejected(
        YellowCardCommitFailure.idempotencyConflict,
      );
    }
    return YellowCardSaved(record: existing, recoveredExisting: true);
  }

  Future<YellowCardCommitResult> _mapDurableFailure(
    DurableCommitFailure failure,
  ) async {
    if (failure.reason.startsWith(_recoverPrefix)) {
      final recordId = failure.reason.substring(_recoverPrefix.length);
      final committed = await memory.getById(recordId);
      if (committed != null && committed.payload is YellowCardPayload) {
        return YellowCardSaved(record: committed, recoveredExisting: true);
      }
      return const YellowCardCommitRejected(
        YellowCardCommitFailure.durableCommitFailure,
      );
    }
    if (failure.reason == _conflictToken) {
      return const YellowCardCommitRejected(
        YellowCardCommitFailure.idempotencyConflict,
      );
    }
    if (failure.reason.startsWith(_admissionPrefix)) {
      final name = failure.reason.substring(_admissionPrefix.length);
      for (final code in YellowCardCommitFailure.values) {
        if (code.name == name) return YellowCardCommitRejected(code);
      }
      return const YellowCardCommitRejected(
        YellowCardCommitFailure.durableCommitFailure,
      );
    }
    return const YellowCardCommitRejected(
      YellowCardCommitFailure.durableCommitFailure,
    );
  }
}
