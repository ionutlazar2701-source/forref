import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  test('NONE_REQUIRED can make an ended-period lineage terminal-eligible', () {
    final records = _bothOrdinaryPeriodsEnded();
    final disposition = resolveAdditionalPlayingPhase(
      const CompetitionRulesContext(
        rulesetId: 'league-two-periods',
        additionalPlayingPhase: AdditionalPlayingPhaseDisposition.noneRequired,
      ),
    );

    expect(disposition, AdditionalPlayingPhaseDisposition.noneRequired);
    expect(
      assessNormalMatchEnd(records: records, disposition: disposition),
      NormalMatchEndEligibility.eligible,
    );
    expect(records.where(_isMatchEnded), isEmpty);
  });

  test('an additional playing phase blocks normal ending', () {
    final disposition = resolveAdditionalPlayingPhase(
      const CompetitionRulesContext(
        rulesetId: 'cup',
        additionalPlayingPhase:
            AdditionalPlayingPhaseDisposition.additionalPlayingPhaseRequired,
      ),
    );

    expect(
      assessNormalMatchEnd(
        records: _bothOrdinaryPeriodsEnded(),
        disposition: disposition,
      ),
      NormalMatchEndEligibility.blockedAdditionalPlayingPhase,
    );
  });

  test('UNRESOLVED blocks normal ending', () {
    expect(
      resolveAdditionalPlayingPhase(null),
      AdditionalPlayingPhaseDisposition.unresolved,
    );
    expect(
      resolveAdditionalPlayingPhase(
        const CompetitionRulesContext(rulesetId: 'unknown-cup'),
      ),
      AdditionalPlayingPhaseDisposition.unresolved,
    );
    expect(
      assessNormalMatchEnd(
        records: _bothOrdinaryPeriodsEnded(),
        disposition: AdditionalPlayingPhaseDisposition.unresolved,
      ),
      NormalMatchEndEligibility.blockedPhaseDispositionUnresolved,
    );
  });

  test('two ordinary periods ended do not establish NONE_REQUIRED', () {
    final records = _bothOrdinaryPeriodsEnded();
    final temporal = TemporalMatchProjection.derive(
      projection: DeterministicMatchProjector(ProductionSemanticsResolver())
          .projectRecords(
        matchId: 'match-1',
        records: records,
        context: const ProjectionContext(evaluatedAuthorityGeneration: 1),
      ),
      records: records,
    );
    final policy = File(
      'lib/semantics/additional_playing_phase_policy.dart',
    ).readAsStringSync();

    expect(temporal.bothOrdinaryPeriodsEnded, isTrue);
    expect(policy, isNot(contains('bothOrdinaryPeriodsEnded')));
    expect(policy, isNot(contains('endedPeriods')));
    expect(
      resolveAdditionalPlayingPhase(
        const CompetitionRulesContext(rulesetId: 'league-two-periods'),
      ),
      AdditionalPlayingPhaseDisposition.unresolved,
    );
    expect(
      assessNormalMatchEnd(
        records: records,
        disposition: AdditionalPlayingPhaseDisposition.unresolved,
      ),
      NormalMatchEndEligibility.blockedPhaseDispositionUnresolved,
    );
  });

  test('score is not an input to phase disposition or terminal eligibility', () {
    final policy = File(
      'lib/semantics/additional_playing_phase_policy.dart',
    ).readAsStringSync();
    final gate = File(
      'lib/projection/normal_match_end_eligibility.dart',
    ).readAsStringSync();

    expect(policy, isNot(contains('score')));
    expect(gate, isNot(contains('score')));
    expect(
      resolveAdditionalPlayingPhase(
        const CompetitionRulesContext(rulesetId: 'league-two-periods'),
      ),
      AdditionalPlayingPhaseDisposition.unresolved,
    );
  });

  test('a shoot-out after the match is not an additional playing period', () {
    final rules = const CompetitionRulesContext(
      rulesetId: 'cup-shoot-out',
      additionalPlayingPhase: AdditionalPlayingPhaseDisposition.noneRequired,
      penaltyShootOutAfterMatchEnd: true,
    );

    expect(
      resolveAdditionalPlayingPhase(rules),
      AdditionalPlayingPhaseDisposition.noneRequired,
    );
    expect(
      rules.additionalPlayingPhase,
      isNot(AdditionalPlayingPhaseDisposition.additionalPlayingPhaseRequired),
    );
    expect(
      assessNormalMatchEnd(
        records: _bothOrdinaryPeriodsEnded(),
        disposition: resolveAdditionalPlayingPhase(rules),
      ),
      NormalMatchEndEligibility.eligible,
    );
  });

  test('an active period blocks normal ending', () {
    expect(
      assessNormalMatchEnd(
        records: [
          _record('start', V1SemanticTypeCode.matchStarted),
          _record(
            'period',
            V1SemanticTypeCode.periodStarted,
            originSequence: 2,
            period: const PeriodIdentity(index: 1),
            relationships: [CausalDependency(targetRecordId: 'start')],
          ),
        ],
        disposition: AdditionalPlayingPhaseDisposition.noneRequired,
      ),
      NormalMatchEndEligibility.blockedActivePeriod,
    );
  });

  test('an open formal suspension blocks normal ending', () {
    expect(
      assessNormalMatchEnd(
        records: [
          _record('start', V1SemanticTypeCode.matchStarted),
          _record(
            'period',
            V1SemanticTypeCode.periodStarted,
            originSequence: 2,
            period: const PeriodIdentity(index: 1),
            relationships: [CausalDependency(targetRecordId: 'start')],
          ),
          _record(
            'susp',
            V1SemanticTypeCode.temporarySuspensionStarted,
            originSequence: 3,
            period: const PeriodIdentity(index: 1),
            relationships: [CausalDependency(targetRecordId: 'period')],
          ),
        ],
        disposition: AdditionalPlayingPhaseDisposition.noneRequired,
      ),
      NormalMatchEndEligibility.blockedOpenSuspension,
    );
  });

  test('MATCH_ABANDONED blocks normal-end eligibility', () {
    final records = [
      ..._bothOrdinaryPeriodsEnded(),
      _record(
        'abandon',
        V1SemanticTypeCode.matchAbandoned,
        originSequence: 6,
      ),
    ];

    expect(
      assessNormalMatchEnd(
        records: records,
        disposition: AdditionalPlayingPhaseDisposition.noneRequired,
      ),
      NormalMatchEndEligibility.blockedAbandoned,
    );
  });

  test('ambiguous temporal lineage blocks normal ending', () {
    expect(
      assessNormalMatchEnd(
        records: [
          _record('start', V1SemanticTypeCode.matchStarted),
          _record(
            'period',
            V1SemanticTypeCode.periodStarted,
            originSequence: 2,
            period: const PeriodIdentity(index: 1),
            relationships: [CausalDependency(targetRecordId: 'start')],
          ),
          _record(
            'other',
            V1SemanticTypeCode.periodStarted,
            originSequence: 3,
            period: const PeriodIdentity(index: 1),
            relationships: [CausalDependency(targetRecordId: 'start')],
          ),
        ],
        disposition: AdditionalPlayingPhaseDisposition.noneRequired,
      ),
      NormalMatchEndEligibility.blockedAmbiguousLineage,
    );
  });

  test('an existing MATCH_ENDED blocks a second normal end', () {
    final records = [
      ..._bothOrdinaryPeriodsEnded(),
      _record(
        'match-end',
        V1SemanticTypeCode.matchEnded,
        originSequence: 6,
        relationships: [CausalDependency(targetRecordId: 'end-2')],
      ),
    ];
    final before = records.length;

    expect(
      assessNormalMatchEnd(
        records: records,
        disposition: AdditionalPlayingPhaseDisposition.noneRequired,
      ),
      NormalMatchEndEligibility.blockedAlreadyEnded,
    );
    expect(records, hasLength(before));
  });

  test('MATCH_ENDED stays distinct and on schema v1', () {
    final ended = V1SemanticContract.byCode[V1SemanticTypeCode.matchEnded]!;
    final periodEnded =
        V1SemanticContract.byCode[V1SemanticTypeCode.periodEnded]!;
    final abandoned =
        V1SemanticContract.byCode[V1SemanticTypeCode.matchAbandoned]!;

    expect(ended.code, isNot(periodEnded.code));
    expect(ended.code, isNot(abandoned.code));
    expect(ended.wireDistinctFrom(periodEnded), isTrue);
    expect(V1SemanticTypeCode.matchEnded.wireValue, 'MATCH_ENDED');
    expect(V1SemanticTypeCode.periodEnded.wireValue, 'PERIOD_ENDED');
    expect(V1SemanticTypeCode.matchAbandoned.wireValue, 'MATCH_ABANDONED');
    expect(V1SemanticTypeCodeWire.parseWire('MATCH_FINISHED'), isNull);
    expect(V1SemanticTypeCodeWire.parseWire('MATCH_COMPLETED'), isNull);
    expect(V1SemanticTypeCodeWire.parseWire('MATCH_TERMINATED'), isNull);
    expect(ended.schemaVersion, 1);
    expect(ended.requiredRecordKind, RecordKind.temporalFact);
    expect(ended.isDurableMatchState, isFalse);
    expect(ended.requiresCausalDependencyOnFinalPeriodEnd, isTrue);
    expect(periodEnded.requiresCausalDependencyOnFinalPeriodEnd, isFalse);
    expect(abandoned.requiresCausalDependencyOnFinalPeriodEnd, isFalse);
    expect(V1SemanticContract.schemaContractVersion, 1);
    expect(
      File('lib/semantics/v2_schema_semantic_interpreter.dart').existsSync(),
      isFalse,
    );
  });

  test('eligibility projection and live match UI do not commit MATCH_ENDED', () {
    final gate = File(
      'lib/projection/normal_match_end_eligibility.dart',
    ).readAsStringSync();
    final page = File(
      '../../apps/referee_phone/lib/features/live_match/live_match_page.dart',
    ).readAsStringSync();

    expect(gate, isNot(contains('commit')));
    expect(page, contains('assessStoredNormalMatchEndEligibility'));
    expect(page, isNot(contains('captureAndCommit')));
  });
}

extension on V1SemanticContract {
  bool wireDistinctFrom(V1SemanticContract other) =>
      code.wireValue != other.code.wireValue;
}

List<MatchRecord> _bothOrdinaryPeriodsEnded() {
  return [
    _record('start', V1SemanticTypeCode.matchStarted),
    _record(
      'period',
      V1SemanticTypeCode.periodStarted,
      originSequence: 2,
      period: const PeriodIdentity(index: 1),
      relationships: [CausalDependency(targetRecordId: 'start')],
    ),
    _record(
      'end',
      V1SemanticTypeCode.periodEnded,
      originSequence: 3,
      period: const PeriodIdentity(index: 1),
      relationships: [CausalDependency(targetRecordId: 'period')],
    ),
    _record(
      'period-2',
      V1SemanticTypeCode.periodStarted,
      originSequence: 4,
      period: const PeriodIdentity(index: 2),
      relationships: [CausalDependency(targetRecordId: 'end')],
    ),
    _record(
      'end-2',
      V1SemanticTypeCode.periodEnded,
      originSequence: 5,
      period: const PeriodIdentity(index: 2),
      relationships: [CausalDependency(targetRecordId: 'period-2')],
    ),
  ];
}

bool _isMatchEnded(MatchRecord record) {
  final payload = record.payload;
  return payload is TemporalTransitionPayload &&
      payload.semanticType == V1SemanticTypeCode.matchEnded;
}

MatchRecord _record(
  String recordId,
  V1SemanticTypeCode code, {
  int originSequence = 1,
  PeriodIdentity? period,
  List<RecordRelationship> relationships = const [],
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-1',
    recordKind: RecordKind.temporalFact,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 4, 12, originSequence),
    originDeviceId: 'dev-a',
    originSequence: originSequence,
    payload: TemporalTransitionPayload(semanticType: code, period: period),
    integrity: const IntegrityMetadata(),
    relationships: relationships,
  );
}
