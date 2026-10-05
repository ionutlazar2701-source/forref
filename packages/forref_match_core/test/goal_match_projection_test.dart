import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  const period = PeriodIdentity(index: 1);
  final anchor = _evidence('anchor', Duration.zero);
  final atEightMinutes = _evidence('goal-ev', const Duration(minutes: 8));

  test('exact temporal context displays derived playing time', () {
    final projection = GoalMatchProjection.derive(
      records: _goalRecords(
        creditedSide: CreditedSide.home,
        goalEvidenceId: atEightMinutes.evidenceId,
        recordedAt: DateTime.utc(2099, 1, 1),
      ),
      evidence: [anchor, atEightMinutes],
    );

    expect(projection.homeScore, 1);
    expect(projection.goals.single.temporal.continuity,
        TemporalContinuityStatus.exactContinuity);
    expect(
      projection.goals.single.temporal.exactPlayingTime,
      const Duration(minutes: 8),
    );
    expect(projection.goals.single.temporal.period, period);
  });

  test('an eight minute goal is not the legacy zero clock', () {
    final projection = GoalMatchProjection.derive(
      records: _goalRecords(
        creditedSide: CreditedSide.away,
        goalEvidenceId: atEightMinutes.evidenceId,
        recordedAt: DateTime.utc(2026, 10, 5, 12),
      ),
      evidence: [anchor, atEightMinutes],
    );

    expect(
      projection.goals.single.temporal.exactPlayingTime,
      isNot(Duration.zero),
    );
    expect(
      projection.goals.single.temporal.exactPlayingTime,
      const Duration(minutes: 8),
    );
  });

  test('bounded continuity does not fabricate an exact minute', () {
    final bounded = TemporalEvidence(
      evidenceId: 'goal-bounded',
      capturedAt: DateTime.utc(2026, 10, 5, 12, 8),
      continuityDomainId: 'domain-a',
      monotonicElapsed: const Duration(minutes: 8),
      monotonicUpperBound: const Duration(minutes: 9),
    );
    final projection = GoalMatchProjection.derive(
      records: _goalRecords(
        creditedSide: CreditedSide.home,
        goalEvidenceId: bounded.evidenceId,
      ),
      evidence: [anchor, bounded],
    );
    final temporal = projection.goals.single.temporal;

    expect(temporal.continuity, TemporalContinuityStatus.boundedContinuity);
    expect(temporal.exactPlayingTime, isNull);
    expect(temporal.playingTimeLowerBound, const Duration(minutes: 8));
    expect(temporal.playingTimeUpperBound, const Duration(minutes: 9));
  });

  test('unresolved continuity does not fabricate an exact minute', () {
    final otherDomain = TemporalEvidence(
      evidenceId: 'goal-other',
      capturedAt: DateTime.utc(2026, 10, 5, 12, 8),
      continuityDomainId: 'domain-b',
      monotonicElapsed: const Duration(minutes: 8),
    );
    final projection = GoalMatchProjection.derive(
      records: _goalRecords(
        creditedSide: CreditedSide.home,
        goalEvidenceId: otherDomain.evidenceId,
      ),
      evidence: [anchor, otherDomain],
    );
    final temporal = projection.goals.single.temporal;

    expect(
      temporal.continuity,
      TemporalContinuityStatus.continuityUnresolved,
    );
    expect(temporal.exactPlayingTime, isNull);
    expect(temporal.playingTimeLowerBound, isNull);
    expect(temporal.playingTimeUpperBound, isNull);
    expect(projection.homeScore, 1);
  });

  test('a legally superseded goal stays in history and does not score', () {
    final records = [
      ..._goalRecords(
        creditedSide: CreditedSide.home,
        goalEvidenceId: atEightMinutes.evidenceId,
        goalId: 'goal-1',
      ),
      _record(
        recordId: 'super-1',
        originSequence: 4,
        recordKind: RecordKind.legalSupersession,
        payload: const LegalSupersessionPayload(),
        relationships: [
          LegalSupersessionTarget(targetRecordId: 'goal-1'),
        ],
      ),
    ];
    final projection = GoalMatchProjection.derive(
      records: records,
      evidence: [anchor, atEightMinutes],
    );

    expect(projection.homeScore, 0);
    expect(projection.awayScore, 0);
    expect(projection.goals, hasLength(1));
    expect(projection.goals.single.legallySuperseded, isTrue);
    expect(projection.goals.single.countsTowardScore, isFalse);
    expect(projection.goals.single.recordId, 'goal-1');
  });

  test('home and away goals both score until one is superseded', () {
    final second = _evidence('goal-2-ev', const Duration(minutes: 12));
    final records = [
      ..._base(anchorId: anchor.evidenceId),
      _goal(
        recordId: 'goal-home',
        originSequence: 3,
        side: CreditedSide.home,
        evidenceId: atEightMinutes.evidenceId,
      ),
      _goal(
        recordId: 'goal-away',
        originSequence: 4,
        side: CreditedSide.away,
        evidenceId: second.evidenceId,
      ),
    ];
    final projection = GoalMatchProjection.derive(
      records: records,
      evidence: [anchor, atEightMinutes, second],
    );

    expect(projection.homeScore, 1);
    expect(projection.awayScore, 1);
    expect(projection.goals, hasLength(2));
  });
}

TemporalEvidence _evidence(String id, Duration elapsed) {
  return TemporalEvidence(
    evidenceId: id,
    capturedAt: DateTime.utc(2026, 10, 5),
    continuityDomainId: 'domain-a',
    monotonicElapsed: elapsed,
  );
}

List<MatchRecord> _goalRecords({
  required CreditedSide creditedSide,
  required String goalEvidenceId,
  String goalId = 'goal-1',
  DateTime? recordedAt,
}) {
  return [
    ..._base(anchorId: 'anchor'),
    _goal(
      recordId: goalId,
      originSequence: 3,
      side: creditedSide,
      evidenceId: goalEvidenceId,
      recordedAt: recordedAt,
    ),
  ];
}

List<MatchRecord> _base({required String anchorId}) {
  return [
    _record(
      recordId: 'start',
      originSequence: 1,
      recordKind: RecordKind.temporalFact,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.matchStarted,
      ),
    ),
    _record(
      recordId: 'period',
      originSequence: 2,
      recordKind: RecordKind.temporalFact,
      payload: TemporalTransitionPayload(
        semanticType: V1SemanticTypeCode.periodStarted,
        period: const PeriodIdentity(index: 1),
      ),
      relationships: [CausalDependency(targetRecordId: 'start')],
      temporalContext: TemporalContext(evidenceIds: [anchorId]),
    ),
  ];
}

MatchRecord _goal({
  required String recordId,
  required int originSequence,
  required CreditedSide side,
  required String evidenceId,
  DateTime? recordedAt,
}) {
  return _record(
    recordId: recordId,
    originSequence: originSequence,
    recordKind: RecordKind.humanDetermination,
    payload: GoalPayload(
      creditedSide: side,
      captureIntentId: 'intent-$recordId',
    ),
    relationships: [CausalDependency(targetRecordId: 'period')],
    temporalContext: TemporalContext(evidenceIds: [evidenceId]),
    recordedAt: recordedAt,
    authority: const AuthorityContext(
      scope: MainRefereeScope(),
      principal: AuthorityPrincipal(principalId: 'ref-1'),
      generation: AuthorityGeneration(value: 1),
    ),
  );
}

MatchRecord _record({
  required String recordId,
  required int originSequence,
  required RecordKind recordKind,
  required MatchRecordPayload payload,
  List<RecordRelationship> relationships = const [],
  TemporalContext? temporalContext,
  DateTime? recordedAt,
  AuthorityContext? authority,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-1',
    recordKind: recordKind,
    schemaVersion: 1,
    recordedAt: recordedAt ?? DateTime.utc(2026, 10, 5, 12, originSequence),
    originDeviceId: 'dev-a',
    originSequence: originSequence,
    payload: payload,
    integrity: const IntegrityMetadata(),
    relationships: relationships,
    temporalContext: temporalContext,
    authorityContext: authority,
  );
}
