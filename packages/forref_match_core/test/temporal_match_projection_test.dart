import 'dart:io';

import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  const context = ProjectionContext(evaluatedAuthorityGeneration: 1);
  final projector = DeterministicMatchProjector(ProductionSemanticsResolver());

  test('match start without a period is authoritative and incomplete', () {
    final temporal = TemporalMatchProjection.derive(
      projection: projector.projectRecords(
        matchId: 'match-1',
        records: [_record('start', V1SemanticTypeCode.matchStarted)],
        context: context,
      ),
      records: [_record('start', V1SemanticTypeCode.matchStarted)],
    );

    expect(temporal.matchStarted, isTrue);
    expect(temporal.activePeriod, isNull);
    expect(temporal.temporallyIncomplete, isTrue);
  });

  test('period 1 is active only with a causal match-start dependency', () {
    final records = [
      _record('start', V1SemanticTypeCode.matchStarted),
      _record(
        'period',
        V1SemanticTypeCode.periodStarted,
        originSequence: 2,
        period: const PeriodIdentity(index: 1),
        relationships: [CausalDependency(targetRecordId: 'start')],
        recordedAt: DateTime.utc(2020, 1, 1),
      ),
    ];
    final temporal = TemporalMatchProjection.derive(
      projection: projector.projectRecords(
        matchId: 'match-1',
        records: records,
        context: context,
      ),
      records: records,
    );

    expect(temporal.matchStarted, isTrue);
    expect(temporal.activePeriod, const PeriodIdentity(index: 1));
    expect(temporal.temporallyIncomplete, isFalse);
  });

  test('recordedAt does not choose the active period', () {
    final earlyPeriod = [
      _record(
        'start',
        V1SemanticTypeCode.matchStarted,
        recordedAt: DateTime.utc(2026, 12, 31),
      ),
      _record(
        'period',
        V1SemanticTypeCode.periodStarted,
        originSequence: 2,
        period: const PeriodIdentity(index: 1),
        relationships: [CausalDependency(targetRecordId: 'start')],
        recordedAt: DateTime.utc(2020, 1, 1),
      ),
    ];
    final temporal = TemporalMatchProjection.derive(
      projection: projector.projectRecords(
        matchId: 'match-1',
        records: earlyPeriod,
        context: context,
      ),
      records: earlyPeriod,
    );

    expect(temporal.activePeriod, const PeriodIdentity(index: 1));
  });

  test('period start without the match-start dependency is not running', () {
    final records = [
      _record('start', V1SemanticTypeCode.matchStarted),
      _record(
        'period',
        V1SemanticTypeCode.periodStarted,
        originSequence: 2,
        period: const PeriodIdentity(index: 1),
      ),
    ];
    final temporal = TemporalMatchProjection.derive(
      projection: projector.projectRecords(
        matchId: 'match-1',
        records: records,
        context: context,
      ),
      records: records,
    );

    expect(temporal.matchStarted, isTrue);
    expect(temporal.activePeriod, isNull);
    expect(temporal.temporallyIncomplete, isTrue);
  });

  test('a second period index does not invent one running period', () {
    final records = [
      _record('start', V1SemanticTypeCode.matchStarted),
      _record(
        'p1',
        V1SemanticTypeCode.periodStarted,
        originSequence: 2,
        period: const PeriodIdentity(index: 1),
        relationships: [CausalDependency(targetRecordId: 'start')],
      ),
      _record(
        'p3',
        V1SemanticTypeCode.periodStarted,
        originSequence: 3,
        period: const PeriodIdentity(index: 3),
        relationships: [CausalDependency(targetRecordId: 'start')],
      ),
    ];
    final temporal = TemporalMatchProjection.derive(
      projection: projector.projectRecords(
        matchId: 'match-1',
        records: records,
        context: context,
      ),
      records: records,
    );

    expect(temporal.matchStarted, isTrue);
    expect(temporal.activePeriod, isNull);
    expect(temporal.temporallyIncomplete, isFalse);
  });

  test('formal suspension stays on the active period', () {
    final records = [
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
    ];
    final temporal = TemporalMatchProjection.derive(
      projection: projector.projectRecords(
        matchId: 'match-1',
        records: records,
        context: context,
      ),
      records: records,
    );

    expect(temporal.formallySuspended, isTrue);
    expect(temporal.activePeriod, const PeriodIdentity(index: 1));
    expect(temporal.temporallyIncomplete, isFalse);
  });

  test('a suspension that misses the period lineage is not formal', () {
    final records = [
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
      ),
    ];
    final temporal = TemporalMatchProjection.derive(
      projection: projector.projectRecords(
        matchId: 'match-1',
        records: records,
        context: context,
      ),
      records: records,
    );

    expect(temporal.formallySuspended, isFalse);
    expect(temporal.activePeriod, const PeriodIdentity(index: 1));
  });

  test('temporal projection source has no elapsed-time authority', () {
    final source = File(
      'lib/projection/temporal_match_projection.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('elapsedSeconds')));
    expect(source, isNot(contains('clockRunning')));
    expect(source, isNot(contains('HALF_TIME')));
    expect(source, isNot(contains('INTERVAL_STARTED')));
    expect(source, isNot(contains('FULL_TIME')));
    expect(source, isNot(contains('MATCH_FINISHED')));
  });

  test('period 1 ended with no later period produces interval-active projection', () {
    final records = [
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
    ];
    final temporal = TemporalMatchProjection.derive(
      projection: projector.projectRecords(
        matchId: 'match-1',
        records: records,
        context: context,
      ),
      records: records,
    );

    expect(temporal.activePeriod, isNull);
    expect(temporal.endedPeriod, const PeriodIdentity(index: 1));
    expect(temporal.intervalActive, isTrue);
    expect(temporal.formallySuspended, isFalse);
    expect(temporal.periodEndAmbiguous, isFalse);
    expect(records, hasLength(3));
  });

  test('a later period start clears interval-active projection', () {
    final records = [
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
        relationships: [CausalDependency(targetRecordId: 'start')],
      ),
    ];
    final temporal = TemporalMatchProjection.derive(
      projection: projector.projectRecords(
        matchId: 'match-1',
        records: records,
        context: context,
      ),
      records: records,
    );

    expect(temporal.intervalActive, isFalse);
    expect(temporal.activePeriod, isNull);
    expect(temporal.endedPeriod, isNull);
  });

  test('period 2 that follows period 1 end is the active period', () {
    final records = [
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
    ];
    final temporal = TemporalMatchProjection.derive(
      projection: projector.projectRecords(
        matchId: 'match-1',
        records: records,
        context: context,
      ),
      records: records,
    );

    expect(temporal.intervalActive, isFalse);
    expect(temporal.activePeriod, const PeriodIdentity(index: 2));
    expect(temporal.endedPeriod, const PeriodIdentity(index: 1));
    expect(temporal.formallySuspended, isFalse);
    expect(anchoredPeriodStart(records, const PeriodIdentity(index: 2))?.recordId, 'period-2');
    expect(anchoredPeriodStart(records, const PeriodIdentity(index: 1))?.recordId, 'period');
  });

  test('match abandoned after period end clears interval-active projection', () {
    final records = [
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
        'abandon',
        V1SemanticTypeCode.matchAbandoned,
        originSequence: 4,
      ),
    ];
    final temporal = TemporalMatchProjection.derive(
      projection: projector.projectRecords(
        matchId: 'match-1',
        records: records,
        context: context,
      ),
      records: records,
    );

    expect(temporal.intervalActive, isFalse);
    expect(temporal.endedPeriod, const PeriodIdentity(index: 1));
  });

  test('period 2 end freezes both periods without an interval or match completion', () {
    final records = [
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
    final temporal = TemporalMatchProjection.derive(
      projection: projector.projectRecords(
        matchId: 'match-1',
        records: records,
        context: context,
      ),
      records: records,
    );

    expect(temporal.activePeriod, isNull);
    expect(temporal.endedPeriod, const PeriodIdentity(index: 2));
    expect(temporal.endedPeriods, [
      const PeriodIdentity(index: 1),
      const PeriodIdentity(index: 2),
    ]);
    expect(temporal.intervalActive, isFalse);
    expect(temporal.bothOrdinaryPeriodsEnded, isTrue);
    expect(temporal.matchNormallyEnded, isFalse);
    expect(temporal.formallySuspended, isFalse);
    expect(
      records.map((record) => (record.payload as TemporalTransitionPayload).semanticType),
      isNot(contains(V1SemanticTypeCode.matchAbandoned)),
    );
    expect(records.where((record) {
      final payload = record.payload as TemporalTransitionPayload;
      return payload.semanticType == V1SemanticTypeCode.periodStarted &&
          payload.period?.index == 3;
    }), isEmpty);
  });

  test('a valid MATCH_ENDED projects normally ended without fixture finality', () {
    final records = [
      ..._ordinaryPeriodsEnded(),
      _record(
        'match-end',
        V1SemanticTypeCode.matchEnded,
        originSequence: 6,
        relationships: [CausalDependency(targetRecordId: 'end-2')],
      ),
    ];
    final temporal = _temporal(projector, context, records);
    final source = File(
      'lib/projection/temporal_match_projection.dart',
    ).readAsStringSync();

    expect(temporal.matchNormallyEnded, isTrue);
    expect(temporal.activePeriod, isNull);
    expect(temporal.formallySuspended, isFalse);
    expect(temporal.intervalActive, isFalse);
    expect(source, isNot(contains('fixtureValidated')));
    expect(source, isNot(contains('resultFinal')));
    expect(source, isNot(contains('organizerApproved')));
    expect(source, isNot(contains('shootoutCompleted')));
  });

  test('a MATCH_ENDED aimed at the wrong period end is not normally ended', () {
    final records = [
      ..._ordinaryPeriodsEnded(),
      _record(
        'match-end',
        V1SemanticTypeCode.matchEnded,
        originSequence: 6,
        relationships: [CausalDependency(targetRecordId: 'end')],
      ),
    ];
    final temporal = _temporal(projector, context, records);

    expect(temporal.matchNormallyEnded, isFalse);
    expect(temporal.bothOrdinaryPeriodsEnded, isTrue);
  });
}

List<MatchRecord> _ordinaryPeriodsEnded() => [
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

TemporalMatchProjection _temporal(
  DeterministicMatchProjector projector,
  ProjectionContext context,
  List<MatchRecord> records,
) {
  return TemporalMatchProjection.derive(
    projection: projector.projectRecords(
      matchId: 'match-1',
      records: records,
      context: context,
    ),
    records: records,
  );
}

MatchRecord _record(
  String recordId,
  V1SemanticTypeCode code, {
  int originSequence = 1,
  PeriodIdentity? period,
  List<RecordRelationship> relationships = const [],
  DateTime? recordedAt,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-1',
    recordKind: RecordKind.temporalFact,
    schemaVersion: 1,
    recordedAt: recordedAt ?? DateTime.utc(2026, 10, 2, 12, originSequence),
    originDeviceId: 'dev-a',
    originSequence: originSequence,
    payload: TemporalTransitionPayload(semanticType: code, period: period),
    integrity: const IntegrityMetadata(),
    relationships: relationships,
  );
}
