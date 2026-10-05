import 'package:forref_match_core/canonical_record_form.dart';
import 'package:forref_match_core/forref_match_core.dart';
import 'package:test/test.dart';

void main() {
  const period = PeriodIdentity(index: 1);

  test('GOAL is the v1 referee determination', () {
    final contract = V1SemanticContract.byCode[V1SemanticTypeCode.goal]!;

    expect(V1SemanticTypeCode.goal.wireValue, 'GOAL');
    expect(V1SemanticTypeCodeWire.parseWire('GOAL'), V1SemanticTypeCode.goal);
    expect(V1SemanticTypeCodeWire.parseWire('GOAL_SCORED'), isNull);
    expect(V1SemanticTypeCodeWire.parseWire('OWN_GOAL'), isNull);
    expect(V1SemanticTypeCode.goal.category, SemanticTypeCategory.event);
    expect(contract.requiredRecordKind, RecordKind.humanDetermination);
    expect(contract.schemaVersion, 1);
    expect(contract.effect, SemanticEffect.sportingEvent);
    expect(contract.createsSportingState, isTrue);
    expect(contract.isDurableMatchState, isFalse);
    expect(contract.projectionFacets, [ProjectionFacet.score]);
    expect(contract.requiresTargetRelationship, isFalse);
  });

  test('a home goal projects home score +1', () {
    final projection = deriveGoalMatchProjection(
      records: [
        ..._activePeriod(),
        _goal('home-1', 3, GoalScoringSide.home),
      ],
      recordedEvidence: const [],
    );

    expect(projection.homeScore, 1);
    expect(projection.awayScore, 0);
    expect(projection.history.single.scoringSide, GoalScoringSide.home);
    expect(projection.history.single.period, period);
    expect(projection.history.single.originSequence, 3);
    expect(projection.history.single.scoringEffectStands, isTrue);
    expect(projection.history.single.playerId, isNull);
    expect(projection.history.single.playerNumber, isNull);
  });

  test('an away goal projects away score +1', () {
    final projection = deriveGoalMatchProjection(
      records: [
        ..._activePeriod(),
        _goal('away-1', 3, GoalScoringSide.away),
      ],
      recordedEvidence: const [],
    );

    expect(projection.homeScore, 0);
    expect(projection.awayScore, 1);
    expect(projection.history.single.scoringSide, GoalScoringSide.away);
  });

  test('multiple goals rebuild the same history and score', () {
    final goals = [
      _goal(
        'g-late-wall',
        3,
        GoalScoringSide.away,
        recordedAt: DateTime.utc(2099),
      ),
      _goal(
        'g-early-wall',
        4,
        GoalScoringSide.home,
        recordedAt: DateTime.utc(2000),
      ),
      _goal('g-third', 5, GoalScoringSide.home),
    ];
    final forward = deriveGoalMatchProjection(
      records: [..._activePeriod(), ...goals],
      recordedEvidence: const [],
    );
    final shuffled = deriveGoalMatchProjection(
      records: [...goals.reversed, ..._activePeriod().reversed],
      recordedEvidence: const [],
    );

    expect(shuffled, forward);
    expect(
      forward.history.map((goal) => goal.recordId),
      ['g-late-wall', 'g-early-wall', 'g-third'],
    );
    expect(forward.homeScore, 2);
    expect(forward.awayScore, 1);
    expect(forward.history.map((goal) => goal.originSequence), [3, 4, 5]);
  });

  test('a later recordedAt does not replace an earlier goal', () {
    final projection = deriveGoalMatchProjection(
      records: [
        ..._activePeriod(),
        _goal(
          'seq-4',
          4,
          GoalScoringSide.home,
          recordedAt: DateTime.utc(2000),
        ),
        _goal(
          'seq-3',
          3,
          GoalScoringSide.away,
          recordedAt: DateTime.utc(2099),
        ),
      ],
      recordedEvidence: const [],
    );

    expect(projection.history.map((goal) => goal.recordId), ['seq-3', 'seq-4']);
    expect(projection.homeScore, 1);
    expect(projection.awayScore, 1);
  });

  test('eight monotonic minutes stay eight minutes when recordedAt is epoch', () {
    final records = [
      ..._activePeriod(anchorId: 'period-anchor'),
      _goal(
        'goal-8',
        3,
        GoalScoringSide.home,
        recordedAt: DateTime.utc(1970),
        evidenceIds: const ['goal-sample'],
      ),
    ];
    final projection = deriveGoalMatchProjection(
      records: records,
      recordedEvidence: [
        _point('period-anchor', Duration.zero, at: DateTime.utc(2099)),
        _point(
          'goal-sample',
          const Duration(minutes: 8),
          at: DateTime.utc(2001),
        ),
      ],
    );

    expect(projection.history.single.temporal.exactElapsed, const Duration(minutes: 8));
    expect(
      projection.history.single.temporal.continuity,
      TemporalContinuityStatus.exactContinuity,
    );
    expect(projection.history.single.temporal.temporallyUncertain, isFalse);
    expect(
      projection.history.single.temporal.exactElapsed,
      isNot(Duration.zero),
    );
    expect(records.last.recordedAt, DateTime.utc(1970));
  });

  test('missing goal evidence is uncertain and is not written as 00:00', () {
    final projection = deriveGoalMatchProjection(
      records: [
        ..._activePeriod(anchorId: 'period-anchor'),
        _goal(
          'goal-unknown',
          3,
          GoalScoringSide.home,
          evidenceIds: const ['missing-sample'],
        ),
      ],
      recordedEvidence: [
        _point('period-anchor', Duration.zero),
      ],
    );

    final reading = projection.history.single.temporal;
    expect(reading.exactElapsed, isNull);
    expect(reading.elapsedLowerBound, isNull);
    expect(reading.elapsedUpperBound, isNull);
    expect(reading.continuity, TemporalContinuityStatus.continuityUnresolved);
    expect(reading.temporallyUncertain, isTrue);
    expect(reading, GoalTemporalReading.uncertain);
    expect(projection.homeScore, 1);
  });

  test('a different continuity domain does not fabricate an exact goal time', () {
    final projection = deriveGoalMatchProjection(
      records: [
        ..._activePeriod(anchorId: 'period-anchor'),
        _goal(
          'goal-cross',
          3,
          GoalScoringSide.away,
          evidenceIds: const ['goal-sample'],
        ),
      ],
      recordedEvidence: [
        _point('period-anchor', Duration.zero, domainId: 'domain-a'),
        _point(
          'goal-sample',
          const Duration(minutes: 8),
          domainId: 'domain-b',
        ),
      ],
    );

    expect(projection.history.single.temporal.exactElapsed, isNull);
    expect(projection.history.single.temporal.temporallyUncertain, isTrue);
    expect(projection.awayScore, 1);
  });

  test('an interval sample stays bounded and does not become an exact second', () {
    final projection = deriveGoalMatchProjection(
      records: [
        ..._activePeriod(anchorId: 'period-anchor'),
        _goal(
          'goal-bounded',
          3,
          GoalScoringSide.home,
          evidenceIds: const ['goal-sample'],
        ),
      ],
      recordedEvidence: [
        _point('period-anchor', const Duration(seconds: 2)),
        TemporalEvidence(
          evidenceId: 'goal-sample',
          capturedAt: DateTime.utc(2099),
          continuityDomainId: 'domain-1',
          monotonicElapsed: const Duration(seconds: 12),
          monotonicUpperBound: const Duration(seconds: 15),
        ),
      ],
    );

    final reading = projection.history.single.temporal;
    expect(reading.continuity, TemporalContinuityStatus.boundedContinuity);
    expect(reading.exactElapsed, isNull);
    expect(reading.elapsedLowerBound, const Duration(seconds: 10));
    expect(reading.elapsedUpperBound, const Duration(seconds: 13));
    expect(reading.temporallyUncertain, isTrue);
  });

  test('an own goal is an ordinary GOAL for the credited side', () {
    final projection = deriveGoalMatchProjection(
      records: [
        ..._activePeriod(),
        _goal('own-1', 3, GoalScoringSide.away),
      ],
      recordedEvidence: const [],
    );

    expect(projection.history.single.scoringSide, GoalScoringSide.away);
    expect(projection.history.single.scoringEffectStands, isTrue);
    expect(projection.homeScore, 0);
    expect(projection.awayScore, 1);
  });

  test('RecordKind.action with a GOAL payload does not score', () {
    final projection = deriveGoalMatchProjection(
      records: [
        ..._activePeriod(),
        _goal('action-goal', 3, GoalScoringSide.home, kind: RecordKind.action),
      ],
      recordedEvidence: const [],
    );

    expect(projection, GoalMatchProjection.empty);
  });

  test('a payload period that disagrees with the causal period does not score', () {
    final records = [
      ..._activePeriod(),
      _transition(
        'end',
        V1SemanticTypeCode.periodEnded,
        originSequence: 3,
        period: period,
        relationships: [CausalDependency(targetRecordId: 'period')],
      ),
      _transition(
        'period-2',
        V1SemanticTypeCode.periodStarted,
        originSequence: 4,
        period: const PeriodIdentity(index: 2),
        relationships: [CausalDependency(targetRecordId: 'end')],
      ),
      _goal(
        'mismatched',
        5,
        GoalScoringSide.home,
        period: const PeriodIdentity(index: 2),
        periodStartId: 'period',
      ),
    ];

    final projection = deriveGoalMatchProjection(
      records: records,
      recordedEvidence: const [],
    );

    expect(projection.history.single.recordId, 'mismatched');
    expect(projection.history.single.scoringEffectStands, isFalse);
    expect(projection.homeScore, 0);
    expect(projection.awayScore, 0);
  });

  test('legal supersession removes the scoring effect and keeps the goal', () {
    final records = [
      ..._activePeriod(),
      _goal('home-1', 3, GoalScoringSide.home),
      _goal('away-1', 4, GoalScoringSide.away),
      _supersession('super-home', 5, 'home-1'),
      _supersession('super-other', 6, 'start'),
    ];
    final forward = deriveGoalMatchProjection(
      records: records,
      recordedEvidence: const [],
    );
    final shuffled = deriveGoalMatchProjection(
      records: [...records.reversed],
      recordedEvidence: const [],
    );

    expect(shuffled, forward);
    expect(forward.history.map((goal) => goal.recordId), ['home-1', 'away-1']);
    expect(forward.history.first.scoringEffectStands, isFalse);
    expect(forward.history.last.scoringEffectStands, isTrue);
    expect(forward.homeScore, 0);
    expect(forward.awayScore, 1);
    expect(records[2].recordId, 'home-1');
    expect(records[2].payload, isA<GoalPayload>());
  });

  test('a correction leaves the standing goal in the score', () {
    final projection = deriveGoalMatchProjection(
      records: [
        ..._activePeriod(),
        _goal('home-1', 3, GoalScoringSide.home, playerNumber: '9'),
        _correction('corr-1', 4, 'home-1'),
      ],
      recordedEvidence: const [],
    );

    expect(projection.history.single.recordId, 'home-1');
    expect(projection.history.single.scoringEffectStands, isTrue);
    expect(projection.history.single.playerNumber, '9');
    expect(projection.homeScore, 1);
  });

  test('a goal that is not bound to the period start does not increment score', () {
    final projection = deriveGoalMatchProjection(
      records: [
        ..._activePeriod(),
        _goal('unbound', 3, GoalScoringSide.home, bound: false),
      ],
      recordedEvidence: const [],
    );

    expect(projection.homeScore, 0);
    expect(projection.awayScore, 0);
    expect(projection.history.single.temporal, GoalTemporalReading.uncertain);
  });

  test('goal payload keeps scoring identity and no stored score or elapsed', () {
    final goal = _goal(
      'goal-1',
      3,
      GoalScoringSide.home,
      playerNumber: '9',
    );
    final same = _goal(
      'goal-1',
      3,
      GoalScoringSide.home,
      playerNumber: '9',
    );
    final otherSide = _goal('goal-1', 3, GoalScoringSide.away, playerNumber: '9');
    final payload = goal.payload as GoalPayload;

    expect(identicalCanonicalRecordContent(goal, same), isTrue);
    expect(identicalCanonicalRecordContent(goal, otherSide), isFalse);
    expect(payload.scoringSide, GoalScoringSide.home);
    expect(payload.period, const PeriodIdentity(index: 1));
    expect(payload.playerNumber, '9');
    expect(payload.playerId, isNull);
    expect(payload.semanticType, V1SemanticTypeCode.goal);
  });

  test('goal admission requires one active period', () {
    expect(
      assessGoalAdmission(records: const [], context: _context()),
      isA<GoalRejected>().having(
        (rejected) => rejected.reason,
        'reason',
        'GOAL requires one active period',
      ),
    );
    expect(
      assessGoalAdmission(
        records: [_transition('start', V1SemanticTypeCode.matchStarted)],
        context: _context(),
      ),
      isA<GoalRejected>().having(
        (rejected) => rejected.reason,
        'reason',
        'GOAL requires one active period',
      ),
    );
  });

  test('goal admission accepts the active period under MAIN_REFEREE', () {
    final admission = assessGoalAdmission(
      records: _activePeriod(withAuthority: true),
      context: _context(),
    );

    expect(admission, isA<GoalAdmitted>());
    final admitted = admission as GoalAdmitted;
    expect(admitted.period.period, period);
    expect(admitted.period.periodStart.recordId, 'period');
    expect(_context().authorityScope, isA<MainRefereeScope>());
  });

  test('goal admission rejects an empty principal and a foreign generation', () {
    expect(
      assessGoalAdmission(
        records: _activePeriod(),
        context: _context(principal: ''),
      ),
      isA<GoalRejected>().having(
        (rejected) => rejected.reason,
        'reason',
        'GOAL requires an authority principal',
      ),
    );
    expect(
      assessGoalAdmission(
        records: _activePeriod(withAuthority: true),
        context: _context(generation: 2),
      ),
      isA<GoalRejected>().having(
        (rejected) => rejected.reason,
        'reason',
        'GOAL capture authority generation does not match',
      ),
    );
    expect(
      assessGoalAdmission(
        records: _activePeriod(),
        context: _context(schemaVersion: 2),
      ),
      isA<GoalRejected>().having(
        (rejected) => rejected.reason,
        'reason',
        'GOAL requires schema version 1',
      ),
    );
  });

  test('goal admission fails closed on ambiguous temporal lineage', () {
    final records = [
      ..._activePeriod(),
      _transition(
        'period-again',
        V1SemanticTypeCode.periodStarted,
        originSequence: 3,
        period: period,
        relationships: [CausalDependency(targetRecordId: 'start')],
      ),
    ];

    expect(
      assessGoalAdmission(records: records, context: _context()),
      isA<GoalRejected>().having(
        (rejected) => rejected.reason,
        'reason',
        'GOAL has ambiguous temporal lineage',
      ),
    );
  });

  test('goal admission rejects a normally ended match', () {
    final records = [
      ..._bothPeriodsEnded(),
      _transition(
        'ended',
        V1SemanticTypeCode.matchEnded,
        originSequence: 6,
        relationships: [CausalDependency(targetRecordId: 'end-2')],
      ),
    ];

    expect(
      assessGoalAdmission(records: records, context: _context()),
      isA<GoalRejected>().having(
        (rejected) => rejected.reason,
        'reason',
        'GOAL requires a match that has not normally ended',
      ),
    );
  });

  test('goal admission rejects an abandoned match', () {
    final records = [
      ..._activePeriod(),
      _transition(
        'abandoned',
        V1SemanticTypeCode.matchAbandoned,
        originSequence: 3,
      ),
    ];

    expect(
      assessGoalAdmission(records: records, context: _context()),
      isA<GoalRejected>().having(
        (rejected) => rejected.reason,
        'reason',
        'GOAL requires a match that has not been abandoned',
      ),
    );
  });

  test('goal admission rejects a formally suspended period', () {
    final records = [
      ..._activePeriod(),
      _transition(
        'susp',
        V1SemanticTypeCode.temporarySuspensionStarted,
        originSequence: 3,
        period: period,
        relationships: [CausalDependency(targetRecordId: 'period')],
      ),
    ];

    expect(
      assessGoalAdmission(records: records, context: _context()),
      isA<GoalRejected>().having(
        (rejected) => rejected.reason,
        'reason',
        'GOAL requires an active playing period',
      ),
    );
  });
}

CaptureContext _context({
  int generation = 1,
  String principal = 'ref-1',
  int schemaVersion = 1,
}) {
  return CaptureContext(
    matchId: 'match-1',
    originDeviceId: 'dev-a',
    authorityScope: const MainRefereeScope(),
    authorityPrincipalId: principal,
    authorityGeneration: generation,
    projectionAuthorityGeneration: 1,
    schemaVersion: schemaVersion,
  );
}

List<MatchRecord> _activePeriod({
  String anchorId = 'period-anchor',
  bool withAuthority = false,
}) {
  return [
    _transition('start', V1SemanticTypeCode.matchStarted, withAuthority: withAuthority),
    _transition(
      'period',
      V1SemanticTypeCode.periodStarted,
      originSequence: 2,
      period: const PeriodIdentity(index: 1),
      relationships: [CausalDependency(targetRecordId: 'start')],
      evidenceIds: [anchorId],
      withAuthority: withAuthority,
    ),
  ];
}

List<MatchRecord> _bothPeriodsEnded() {
  return [
    ..._activePeriod(),
    _transition(
      'end',
      V1SemanticTypeCode.periodEnded,
      originSequence: 3,
      period: const PeriodIdentity(index: 1),
      relationships: [CausalDependency(targetRecordId: 'period')],
    ),
    _transition(
      'period-2',
      V1SemanticTypeCode.periodStarted,
      originSequence: 4,
      period: const PeriodIdentity(index: 2),
      relationships: [CausalDependency(targetRecordId: 'end')],
    ),
    _transition(
      'end-2',
      V1SemanticTypeCode.periodEnded,
      originSequence: 5,
      period: const PeriodIdentity(index: 2),
      relationships: [CausalDependency(targetRecordId: 'period-2')],
    ),
  ];
}

MatchRecord _transition(
  String recordId,
  V1SemanticTypeCode code, {
  int originSequence = 1,
  PeriodIdentity? period,
  List<RecordRelationship> relationships = const [],
  List<String> evidenceIds = const [],
  bool withAuthority = false,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-1',
    recordKind: RecordKind.temporalFact,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 5, 12, originSequence),
    originDeviceId: 'dev-a',
    originSequence: originSequence,
    payload: TemporalTransitionPayload(semanticType: code, period: period),
    integrity: const IntegrityMetadata(),
    relationships: relationships,
    temporalContext: evidenceIds.isEmpty
        ? null
        : TemporalContext(evidenceIds: evidenceIds),
    authorityContext: withAuthority ? _authority() : null,
  );
}

MatchRecord _goal(
  String recordId,
  int originSequence,
  GoalScoringSide side, {
  DateTime? recordedAt,
  List<String> evidenceIds = const [],
  bool bound = true,
  String? playerNumber,
  PeriodIdentity period = const PeriodIdentity(index: 1),
  String periodStartId = 'period',
  RecordKind kind = RecordKind.humanDetermination,
}) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-1',
    recordKind: kind,
    schemaVersion: 1,
    recordedAt: recordedAt ?? DateTime.utc(2026, 10, 5, 12, originSequence),
    originDeviceId: 'dev-a',
    originSequence: originSequence,
    payload: GoalPayload(
      scoringSide: side,
      period: period,
      playerNumber: playerNumber,
    ),
    integrity: const IntegrityMetadata(),
    relationships: bound
        ? [CausalDependency(targetRecordId: periodStartId)]
        : const [],
    temporalContext: TemporalContext(evidenceIds: evidenceIds),
    authorityContext: _authority(),
  );
}

AuthorityContext _authority() {
  return const AuthorityContext(
    scope: MainRefereeScope(),
    principal: AuthorityPrincipal(principalId: 'ref-1'),
    generation: AuthorityGeneration(value: 1),
  );
}

MatchRecord _supersession(
  String recordId,
  int originSequence,
  String targetId,
) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-1',
    recordKind: RecordKind.legalSupersession,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 5, 12, originSequence),
    originDeviceId: 'dev-a',
    originSequence: originSequence,
    payload: const LegalSupersessionPayload(),
    integrity: const IntegrityMetadata(),
    relationships: [LegalSupersessionTarget(targetRecordId: targetId)],
    authorityContext: _authority(),
  );
}

MatchRecord _correction(
  String recordId,
  int originSequence,
  String targetId,
) {
  return MatchRecord(
    recordId: recordId,
    matchId: 'match-1',
    recordKind: RecordKind.correction,
    schemaVersion: 1,
    recordedAt: DateTime.utc(2026, 10, 5, 12, originSequence),
    originDeviceId: 'dev-a',
    originSequence: originSequence,
    payload: const CorrectionPayload(),
    integrity: const IntegrityMetadata(),
    relationships: [CorrectionTarget(targetRecordId: targetId)],
    authorityContext: _authority(),
  );
}

TemporalEvidence _point(
  String evidenceId,
  Duration monotonic, {
  String domainId = 'domain-1',
  DateTime? at,
}) {
  return TemporalEvidence(
    evidenceId: evidenceId,
    capturedAt: at ?? DateTime.utc(2099),
    continuityDomainId: domainId,
    monotonicElapsed: monotonic,
  );
}
