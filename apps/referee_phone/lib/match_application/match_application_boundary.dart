import 'package:forref_match_core/forref_match_core.dart';
import 'package:forref_match_persistence/forref_match_persistence.dart';

import 'authoritative_capture_command.dart';
import 'kick_off_authority.dart';
import 'match_commit_port.dart';
import 'match_projection_read_port.dart';

/// Phone application boundary over new FORREF Match Core authority.
///
/// Commit delegates only to [SqliteDurableMatchStore]. Projection is rebuilt
/// from committed records through [ProductionSemanticsResolver] and
/// [DeterministicMatchProjector]. This type does not mutate or notify UI state.
final class MatchApplicationBoundary
    implements MatchCommitPort, MatchProjectionReadPort {
  MatchApplicationBoundary({
    required SqliteDurableMatchStore store,
    AuthoritativeRecordBuilder? recordBuilder,
    DeterministicMatchProjector? projector,
  })  : _store = store,
        _recordBuilder = recordBuilder ??
            AuthoritativeRecordBuilder(
              identityGenerator: const _RequiredIdentityGenerator(),
            ),
        _projector = projector ??
            DeterministicMatchProjector(ProductionSemanticsResolver());

  final SqliteDurableMatchStore _store;
  final AuthoritativeRecordBuilder _recordBuilder;
  final DeterministicMatchProjector _projector;

  /// Separate durable store from legacy Drift. Not for legacy match flows.
  SqliteDurableMatchStore get durableStore => _store;

  AuthoritativeRecordBuilder get recordBuilder => _recordBuilder;

  /// Ordered Kick-off: `MATCH_STARTED`, then `PERIOD_STARTED`.
  ///
  /// Each record is its own D1 commit. A failed period start leaves the
  /// match-start record in place. Recovery reads Match Memory before writing.
  Future<KickOffAuthorityResult> commitKickOff(
    CaptureContext context, {
    required PeriodIdentity period,
    Future<TemporalContext> Function()? periodAnchor,
  }) async {
    final existing = await _store.readCommittedForMatch(context.matchId);
    if (_matchStartedCount(existing) > 1) {
      return const KickOffAuthorityRejected(
        reason: 'MATCH_STARTED already committed',
      );
    }

    var matchStarted = _matchStartedRecord(existing);
    final existingPeriod = _periodStartedRecord(existing, period);
    if (matchStarted != null && existingPeriod != null) {
      return const KickOffAlreadyStarted();
    }

    if (matchStarted == null) {
      final started = await commitMatchStarted(context);
      if (started is! DurableCommitSuccess) {
        final afterFailure = await _store.readCommittedForMatch(context.matchId);
        matchStarted = _matchStartedRecord(afterFailure);
        if (matchStarted == null) {
          final reason = started is DurableCommitFailure
              ? started.reason
              : 'MATCH_STARTED was not saved';
          return KickOffAuthorityRejected(reason: reason);
        }
      } else {
        final afterStart = await _store.readCommittedForMatch(context.matchId);
        matchStarted = _matchStartedRecord(afterStart);
        if (matchStarted == null) {
          return const KickOffAuthorityRejected(
            reason: 'MATCH_STARTED was not saved',
          );
        }
      }
    }

    if (_periodStartedRecord(
          await _store.readCommittedForMatch(context.matchId),
          period,
        ) !=
        null) {
      return const KickOffAlreadyStarted();
    }

    TemporalContext? periodTemporal;
    if (periodAnchor != null) {
      try {
        periodTemporal = await periodAnchor();
      } catch (error) {
        return KickOffMatchStartedIncomplete(
          matchStartedRecordId: matchStarted.recordId,
          periodFailureReason: 'period anchor was not captured: $error',
        );
      }
    }

    final periodResult = await commitPeriodStarted(
      context,
      period: period,
      matchStartedRecordId: matchStarted.recordId,
      temporalContext: periodTemporal,
    );
    if (periodResult is DurableCommitSuccess) {
      return KickOffAuthorityCommitted(
        matchStartedRecordId: matchStarted.recordId,
        periodStartedRecordId: periodResult.committedRecordId,
      );
    }
    final reason = periodResult is DurableCommitFailure
        ? periodResult.reason
        : 'PERIOD_STARTED was not saved';
    if (reason.contains('already committed')) {
      return const KickOffAlreadyStarted();
    }
    return KickOffMatchStartedIncomplete(
      matchStartedRecordId: matchStarted.recordId,
      periodFailureReason: reason,
    );
  }

  /// Authoritative match start. Fails closed when this match already has
  /// `MATCH_STARTED`. The guard runs inside the durable commit transaction.
  Future<DurableCommitResult> commitMatchStarted(CaptureContext context) {
    final request = _recordBuilder.build(
      context: context,
      recordKind: RecordKind.temporalFact,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.matchStarted,
        domainContractVersion: context.domainContractVersion,
        competitionRulesContext: context.competitionRulesContext,
      ),
      integrity: const IntegrityMetadata(),
    );
    return _store.commitAtNextOriginSequence(
      request,
      rejectCommitted: (records) {
        for (final record in records) {
          final payload = record.payload;
          if (record.recordKind == RecordKind.temporalFact &&
              payload is TemporalTransitionPayload &&
              payload.semanticType == V1SemanticTypeCode.matchStarted) {
            return 'MATCH_STARTED already committed';
          }
        }
        return null;
      },
    );
  }

  /// Authoritative period start. Fails closed inside the commit transaction
  /// when `MATCH_STARTED` is missing or this period already started.
  Future<DurableCommitResult> commitPeriodStarted(
    CaptureContext context, {
    required PeriodIdentity period,
    required String matchStartedRecordId,
    TemporalContext? temporalContext,
  }) {
    final request = _recordBuilder.build(
      context: context,
      recordKind: RecordKind.temporalFact,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.periodStarted,
        period: period,
        domainContractVersion: context.domainContractVersion,
        competitionRulesContext: context.competitionRulesContext,
      ),
      integrity: const IntegrityMetadata(),
      relationships: [
        CausalDependency(targetRecordId: matchStartedRecordId),
      ],
      temporalContext: temporalContext,
    );
    return _store.commitAtNextOriginSequence(
      request,
      rejectCommitted: (records) {
        if (_matchStartedCount(records) > 1) {
          return 'MATCH_STARTED already committed';
        }
        final matchStarted = _matchStartedRecord(records);
        if (matchStarted == null) {
          return 'PERIOD_STARTED requires committed MATCH_STARTED';
        }
        if (matchStarted.recordId != matchStartedRecordId) {
          return 'PERIOD_STARTED dependency is not the committed MATCH_STARTED';
        }
        if (period.index != 1) {
          return 'PERIOD_STARTED on MATCH_STARTED is only valid for period 1';
        }
        if (_periodStartedRecord(records, period) != null) {
          return 'PERIOD_STARTED already committed for period ${period.index}';
        }
        return null;
      },
    );
  }

  /// Starts the next period after an ended period. This cutover accepts
  /// period 2 only, causally tied to `PERIOD_ENDED` of period 1.
  ///
  /// Does not reset Period 1 and does not write a legacy second half.
  Future<DurableCommitResult> commitNextPeriodStarted(
    CaptureContext context, {
    required PeriodIdentity period,
    required String periodEndedRecordId,
    required TemporalContext temporalContext,
  }) {
    final request = _recordBuilder.build(
      context: context,
      recordKind: RecordKind.temporalFact,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.periodStarted,
        period: period,
        domainContractVersion: context.domainContractVersion,
        competitionRulesContext: context.competitionRulesContext,
      ),
      integrity: const IntegrityMetadata(),
      relationships: [
        CausalDependency(targetRecordId: periodEndedRecordId),
      ],
      temporalContext: temporalContext,
    );
    if (temporalContext.evidenceIds.isEmpty) {
      return Future<DurableCommitResult>.value(
        DurableCommitFailure(
          recordId: request.recordId,
          reason: 'PERIOD_STARTED requires temporal anchor evidence',
        ),
      );
    }
    return _store.commitAtNextOriginSequence(
      request,
      rejectCommitted: (records) {
        if (_matchStartedCount(records) != 1) {
          return 'PERIOD_STARTED requires one committed MATCH_STARTED';
        }
        if (period.index != 2) {
          return 'PERIOD_STARTED next period index is not 2';
        }
        final lineage = periodLineage(records: records);
        if (lineage.ambiguous || lineage.endAmbiguous) {
          return 'PERIOD_STARTED has ambiguous period lineage';
        }
        if (lineage.starts.any((start) {
          final payload = start.payload;
          return payload is TemporalTransitionPayload &&
              payload.period?.index == 2;
        })) {
          return 'PERIOD_STARTED already committed for period 2';
        }
        if (lineage.activeStart != null) {
          return 'PERIOD_STARTED requires no active period';
        }
        if (!lineage.intervalActive ||
            lineage.latestEnded?.index != 1) {
          return 'PERIOD_STARTED requires Period 1 ended';
        }
        final periodOne = lineage.starts.single;
        final ends = [
          for (final record in records)
            if (_isTemporal(record, V1SemanticTypeCode.periodEnded) &&
                record.relationships.any(
                  (link) =>
                      link is CausalDependency &&
                      link.targetRecordId == periodOne.recordId,
                ))
              record,
        ];
        if (ends.length != 1 || ends.single.recordId != periodEndedRecordId) {
          return 'PERIOD_STARTED does not match PERIOD_ENDED for period 1';
        }
        return null;
      },
    );
  }

  /// Formal suspension of the active period. A later suspension is valid after
  /// the previous one has been closed. Fails closed while one is still open.
  ///
  /// Does not end the suspension and does not pause a legacy match clock.
  Future<DurableCommitResult> commitTemporarySuspensionStarted(
    CaptureContext context, {
    required PeriodIdentity period,
    required String periodStartedRecordId,
    required TemporalContext temporalContext,
  }) {
    final request = _recordBuilder.build(
      context: context,
      recordKind: RecordKind.temporalFact,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.temporarySuspensionStarted,
        period: period,
        domainContractVersion: context.domainContractVersion,
        competitionRulesContext: context.competitionRulesContext,
      ),
      integrity: const IntegrityMetadata(),
      relationships: [
        CausalDependency(targetRecordId: periodStartedRecordId),
      ],
      temporalContext: temporalContext,
    );
    if (temporalContext.evidenceIds.isEmpty) {
      return Future<DurableCommitResult>.value(
        DurableCommitFailure(
          recordId: request.recordId,
          reason:
              'TEMPORARY_SUSPENSION_STARTED requires temporal boundary evidence',
        ),
      );
    }
    return _store.commitAtNextOriginSequence(
      request,
      rejectCommitted: (records) {
        if (_matchStartedCount(records) != 1) {
          return 'TEMPORARY_SUSPENSION_STARTED requires one committed MATCH_STARTED';
        }
        final active = _singleActivePeriodStart(records);
        if (active == null) {
          final requested = [
            for (final record in records)
              if (record.recordId == periodStartedRecordId) record,
          ];
          if (requested.length == 1 &&
              _periodEndCount(records, requested.single) != 0) {
            return 'TEMPORARY_SUSPENSION_STARTED requires an unfinished period';
          }
          return 'TEMPORARY_SUSPENSION_STARTED requires one active period';
        }
        final payload = active.payload;
        if (payload is! TemporalTransitionPayload ||
            payload.period?.index != period.index ||
            active.recordId != periodStartedRecordId) {
          return 'TEMPORARY_SUSPENSION_STARTED does not match the active period';
        }
        if (_periodEndCount(records, active) != 0) {
          return 'TEMPORARY_SUSPENSION_STARTED requires an unfinished period';
        }
        if (_openFormalSuspensions(records, active).isNotEmpty) {
          return 'TEMPORARY_SUSPENSION_STARTED already committed';
        }
        return null;
      },
    );
  }

  /// Declares that the referee has normally ended the match.
  ///
  /// Fails closed unless [assessNormalMatchEnd] is eligible and
  /// [periodEndedRecordId] is the final completed playing period. Does not
  /// write legacy full-time and does not capture a shoot-out.
  /// Reads competition rules from [context]. Does not accept ad hoc UI rules.
  Future<DurableCommitResult> commitMatchEnded(
    CaptureContext context, {
    required String periodEndedRecordId,
  }) {
    final rules = context.competitionRulesContext;
    final request = _recordBuilder.build(
      context: context,
      recordKind: RecordKind.temporalFact,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.matchEnded,
        domainContractVersion: context.domainContractVersion,
        competitionRulesContext: rules,
      ),
      integrity: const IntegrityMetadata(),
      relationships: [
        CausalDependency(targetRecordId: periodEndedRecordId),
      ],
    );
    if (rules == null) {
      return Future<DurableCommitResult>.value(
        DurableCommitFailure(
          recordId: request.recordId,
          reason: 'MATCH_ENDED requires match competition rules context',
        ),
      );
    }
    return _store.commitAtNextOriginSequence(
      request,
      rejectCommitted: (records) {
        final eligibility = assessNormalMatchEnd(
          records: records,
          disposition: resolveAdditionalPlayingPhase(rules),
        );
        if (eligibility != NormalMatchEndEligibility.eligible) {
          return 'MATCH_ENDED ${eligibility.name}';
        }
        final finalEnd = finalCompletedPeriodEnd(records: records);
        if (finalEnd == null || finalEnd.recordId != periodEndedRecordId) {
          return 'MATCH_ENDED does not match the final PERIOD_ENDED';
        }
        return null;
      },
    );
  }

  /// Ends the unfinished active period. Fails closed inside the commit
  /// transaction. A display threshold does not call this.
  ///
  /// Period 2 uses this same commit. It does not complete the match, start
  /// another period, or write a legacy half-time or full-time.
  Future<DurableCommitResult> commitPeriodEnded(
    CaptureContext context, {
    required PeriodIdentity period,
    required String periodStartedRecordId,
    required TemporalContext temporalContext,
  }) {
    final request = _recordBuilder.build(
      context: context,
      recordKind: RecordKind.temporalFact,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.periodEnded,
        period: period,
        domainContractVersion: context.domainContractVersion,
        competitionRulesContext: context.competitionRulesContext,
      ),
      integrity: const IntegrityMetadata(),
      relationships: [
        CausalDependency(targetRecordId: periodStartedRecordId),
      ],
      temporalContext: temporalContext,
    );
    if (temporalContext.evidenceIds.isEmpty) {
      return Future<DurableCommitResult>.value(
        DurableCommitFailure(
          recordId: request.recordId,
          reason: 'PERIOD_ENDED requires temporal boundary evidence',
        ),
      );
    }
    return _store.commitAtNextOriginSequence(
      request,
      rejectCommitted: (records) {
        if (_matchStartedCount(records) != 1) {
          return 'PERIOD_ENDED requires one committed MATCH_STARTED';
        }
        final lineage = periodLineage(records: records);
        if (lineage.ambiguous || lineage.endAmbiguous) {
          return 'PERIOD_ENDED has ambiguous active periods';
        }
        final active = lineage.activeStart;
        if (active == null) {
          final ended = [
            for (final start in lineage.starts)
              if (start.payload is TemporalTransitionPayload &&
                  (start.payload as TemporalTransitionPayload).period?.index ==
                      period.index &&
                  start.recordId == periodStartedRecordId &&
                  _periodEndCount(records, start) != 0)
                start,
          ];
          if (ended.isNotEmpty) {
            return 'PERIOD_ENDED already committed';
          }
          return 'PERIOD_ENDED requires one active period';
        }
        final payload = active.payload;
        if (payload is! TemporalTransitionPayload ||
            payload.period?.index != period.index ||
            active.recordId != periodStartedRecordId) {
          return 'PERIOD_ENDED does not match the active period';
        }
        if (_periodEndCount(records, active) != 0) {
          return 'PERIOD_ENDED already committed';
        }
        if (_openFormalSuspensions(records, active).isNotEmpty) {
          return 'PERIOD_ENDED requires an active period without an open formal suspension';
        }
        return null;
      },
    );
  }

  /// Resumption of the open formal suspension. Fails closed inside the commit
  /// transaction unless that suspension is still open for the active period.
  ///
  /// Does not end the period and does not write a legacy match clock.
  Future<DurableCommitResult> commitTemporarySuspensionEnded(
    CaptureContext context, {
    required PeriodIdentity period,
    required String suspensionStartedRecordId,
    required TemporalContext temporalContext,
  }) {
    final request = _recordBuilder.build(
      context: context,
      recordKind: RecordKind.temporalFact,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.temporarySuspensionEnded,
        period: period,
        domainContractVersion: context.domainContractVersion,
        competitionRulesContext: context.competitionRulesContext,
      ),
      integrity: const IntegrityMetadata(),
      relationships: [
        CausalDependency(targetRecordId: suspensionStartedRecordId),
      ],
      temporalContext: temporalContext,
    );
    if (temporalContext.evidenceIds.isEmpty) {
      return Future<DurableCommitResult>.value(
        DurableCommitFailure(
          recordId: request.recordId,
          reason: 'TEMPORARY_SUSPENSION_ENDED requires temporal anchor evidence',
        ),
      );
    }
    return _store.commitAtNextOriginSequence(
      request,
      rejectCommitted: (records) {
        if (_matchStartedCount(records) != 1) {
          return 'TEMPORARY_SUSPENSION_ENDED requires one committed MATCH_STARTED';
        }
        final active = _singleActivePeriodStart(records);
        if (active == null) {
          return 'TEMPORARY_SUSPENSION_ENDED requires one active period';
        }
        final payload = active.payload;
        if (payload is! TemporalTransitionPayload ||
            payload.period?.index != period.index) {
          return 'TEMPORARY_SUSPENSION_ENDED does not match the active period';
        }
        if (_periodEndCount(records, active) != 0) {
          return 'TEMPORARY_SUSPENSION_ENDED requires an unfinished period';
        }
        final starts = _formalSuspensions(records, active);
        final targeted = [
          for (final start in starts)
            if (start.recordId == suspensionStartedRecordId) start,
        ];
        if (targeted.isNotEmpty &&
            _resumptionCount(records, targeted.single) != 0) {
          return 'TEMPORARY_SUSPENSION_ENDED already committed';
        }
        final open = _openFormalSuspensions(records, active);
        if (open.isEmpty) {
          return 'TEMPORARY_SUSPENSION_ENDED requires an open formal suspension';
        }
        if (open.length != 1) {
          return 'TEMPORARY_SUSPENSION_ENDED has ambiguous open suspensions';
        }
        if (open.single.recordId != suspensionStartedRecordId) {
          return 'TEMPORARY_SUSPENSION_ENDED does not match the open suspension';
        }
        return null;
      },
    );
  }

  /// GOAL: the main referee has determined that a valid goal stands for one side.
  ///
  /// The record kind is [RecordKind.humanDetermination]. [period] and
  /// [temporalContext] are placement context and must agree with the active
  /// `PERIOD_STARTED`. Does not read a legacy clock, does not store elapsed
  /// time, and does not write a legacy match event or score. Fails closed
  /// inside the durable transaction.
  Future<DurableCommitResult> commitGoal(
    CaptureContext context, {
    required GoalScoringSide scoringSide,
    required TemporalContext temporalContext,
    String? playerId,
    String? playerNumber,
  }) async {
    final prepared = assessGoalAdmission(
      records: await _store.readCommittedForMatch(context.matchId),
      context: context,
    );
    if (prepared is GoalRejected) {
      return DurableCommitFailure(
        recordId: 'goal-not-committed',
        reason: prepared.reason,
      );
    }
    final admitted = (prepared as GoalAdmitted).period;
    final request = _recordBuilder.build(
      context: context,
      recordKind: RecordKind.humanDetermination,
      payload: GoalPayload(
        scoringSide: scoringSide,
        period: admitted.period,
        playerId: _optionalGoalIdentity(playerId),
        playerNumber: _optionalGoalIdentity(playerNumber),
        domainContractVersion: context.domainContractVersion,
        competitionRulesContext: context.competitionRulesContext,
      ),
      integrity: const IntegrityMetadata(),
      relationships: [
        CausalDependency(targetRecordId: admitted.periodStart.recordId),
      ],
      temporalContext: temporalContext,
    );
    return _store.commitAtNextOriginSequence(
      request,
      rejectCommitted: (records) {
        final admission = assessGoalAdmission(
          records: records,
          context: context,
        );
        if (admission is GoalRejected) return admission.reason;
        final period = (admission as GoalAdmitted).period;
        if (period.periodStart.recordId != admitted.periodStart.recordId ||
            period.period.index != admitted.period.index) {
          return 'GOAL does not match the active period';
        }
        return null;
      },
    );
  }

  /// Constructs an authoritative record, allocates the next origin sequence
  /// atomically, and durable-commits. UI must not choose originSequence.
  Future<DurableCommitResult> captureAndCommit(
    AuthoritativeCaptureCommand command,
  ) async {
    final request = _recordBuilder.build(
      context: command.context,
      recordKind: command.recordKind,
      payload: command.payload,
      integrity: command.integrity,
      relationships: command.relationships,
      temporalContext: command.temporalContext,
      recordedAt: command.recordedAt,
    );
    return _store.commitAtNextOriginSequence(request);
  }

  @override
  Future<DurableCommitResult> commit(MatchRecord record) {
    return _store.commit(record);
  }

  @override
  Future<MatchProjectionState> project(
    String matchId, {
    required int evaluatedAuthorityGeneration,
  }) {
    return _projector.project(
      _store,
      matchId,
      ProjectionContext(evaluatedAuthorityGeneration: evaluatedAuthorityGeneration),
    );
  }

  Future<void> close() => _store.close();
}

/// Forces explicit [RecordIdentityGenerator] injection at composition root.
final class _RequiredIdentityGenerator implements RecordIdentityGenerator {
  const _RequiredIdentityGenerator();

  @override
  String newRecordId() {
    throw StateError(
      'RecordIdentityGenerator must be supplied through MatchApplicationComposition',
    );
  }
}

bool _isTemporal(MatchRecord record, V1SemanticTypeCode code) {
  final payload = record.payload;
  return record.recordKind == RecordKind.temporalFact &&
      payload is TemporalTransitionPayload &&
      payload.semanticType == code;
}

int _matchStartedCount(List<MatchRecord> records) {
  return records
      .where((record) => _isTemporal(record, V1SemanticTypeCode.matchStarted))
      .length;
}

MatchRecord? _matchStartedRecord(List<MatchRecord> records) {
  for (final record in records) {
    if (_isTemporal(record, V1SemanticTypeCode.matchStarted)) return record;
  }
  return null;
}

MatchRecord? _periodStartedRecord(
  List<MatchRecord> records,
  PeriodIdentity period,
) {
  for (final record in records) {
    final payload = record.payload;
    if (_isTemporal(record, V1SemanticTypeCode.periodStarted) &&
        payload is TemporalTransitionPayload &&
        payload.period?.index == period.index) {
      return record;
    }
  }
  return null;
}

MatchRecord? _singleActivePeriodStart(List<MatchRecord> records) {
  final lineage = periodLineage(records: records);
  if (lineage.ambiguous || lineage.endAmbiguous) return null;
  return lineage.activeStart;
}

int _periodEndCount(List<MatchRecord> records, MatchRecord periodStart) {
  final payload = periodStart.payload;
  if (payload is! TemporalTransitionPayload || payload.period == null) {
    return 0;
  }
  final index = payload.period!.index;
  var count = 0;
  for (final record in records) {
    final ended = record.payload;
    if (!_isTemporal(record, V1SemanticTypeCode.periodEnded) ||
        ended is! TemporalTransitionPayload ||
        ended.period?.index != index) {
      continue;
    }
    final dependsOnPeriod = record.relationships.any(
      (link) =>
          link is CausalDependency &&
          link.targetRecordId == periodStart.recordId,
    );
    if (dependsOnPeriod) count++;
  }
  return count;
}

List<MatchRecord> _formalSuspensions(
  List<MatchRecord> records,
  MatchRecord periodStart,
) {
  final payload = periodStart.payload;
  if (payload is! TemporalTransitionPayload || payload.period == null) {
    return const [];
  }
  final index = payload.period!.index;
  final starts = <MatchRecord>[];
  for (final record in records) {
    final suspension = record.payload;
    if (!_isTemporal(record, V1SemanticTypeCode.temporarySuspensionStarted) ||
        suspension is! TemporalTransitionPayload ||
        suspension.period?.index != index) {
      continue;
    }
    final dependsOnPeriod = record.relationships.any(
      (link) =>
          link is CausalDependency &&
          link.targetRecordId == periodStart.recordId,
    );
    if (dependsOnPeriod) starts.add(record);
  }
  return starts;
}

List<MatchRecord> _openFormalSuspensions(
  List<MatchRecord> records,
  MatchRecord periodStart,
) {
  return [
    for (final start in _formalSuspensions(records, periodStart))
      if (_resumptionCount(records, start) == 0) start,
  ];
}

int _resumptionCount(List<MatchRecord> records, MatchRecord suspensionStart) {
  final payload = suspensionStart.payload;
  if (payload is! TemporalTransitionPayload || payload.period == null) {
    return 0;
  }
  final index = payload.period!.index;
  var count = 0;
  for (final record in records) {
    final resumption = record.payload;
    if (!_isTemporal(record, V1SemanticTypeCode.temporarySuspensionEnded) ||
        resumption is! TemporalTransitionPayload ||
        resumption.period?.index != index) {
      continue;
    }
    final closesStart = record.relationships.any(
      (link) =>
          link is CausalDependency &&
          link.targetRecordId == suspensionStart.recordId,
    );
    if (closesStart) count++;
  }
  return count;
}

/// Blank player text is omitted. It is not a player identity.
String? _optionalGoalIdentity(String? value) {
  if (value == null || value.isEmpty) return null;
  return value;
}
